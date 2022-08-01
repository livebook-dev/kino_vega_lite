defmodule KinoVegaLite.ChartCell do
  @moduledoc false

  use Kino.JS, assets_path: "lib/assets/chart_cell"
  use Kino.JS.Live
  use Kino.SmartCell, name: "Chart"

  @as_int ["width", "height"]
  @as_atom [
    "data_variable",
    "chart_type",
    "x_field_type",
    "y_field_type",
    "color_field_type",
    "x_field_aggregate",
    "y_field_aggregate",
    "color_field_aggregate"
  ]

  @count_field "__count__"

  @impl true
  def init(attrs, ctx) do
    root_fields = %{
      "chart_title" => attrs["chart_title"],
      "width" => attrs["width"],
      "height" => attrs["height"]
    }

    layers =
      attrs["layers"] ||
        [
          %{
            "chart_type" => "point",
            "data_variable" => nil,
            "x_field" => nil,
            "y_field" => nil,
            "color_field" => nil,
            "x_field_type" => nil,
            "y_field_type" => nil,
            "color_field_type" => nil,
            "x_field_aggregate" => nil,
            "y_field_aggregate" => nil,
            "color_field_aggregate" => nil
          }
        ]

    ctx =
      assign(ctx,
        root_fields: root_fields,
        layers: layers,
        data_options: [],
        vl_alias: nil,
        missing_dep: missing_dep()
      )

    {:ok, ctx, reevaluate_on_change: true}
  end

  @impl true
  def scan_binding(pid, binding, env) do
    data_options =
      for {key, val} <- binding,
          is_atom(key),
          columns = columns_for(val),
          do: %{variable: Atom.to_string(key), columns: columns}

    vl_alias = vl_alias(env)
    send(pid, {:scan_binding_result, data_options, vl_alias})
  end

  @impl true
  def handle_connect(ctx) do
    payload = %{
      root_fields: ctx.assigns.root_fields,
      layers: ctx.assigns.layers,
      missing_dep: ctx.assigns.missing_dep,
      data_options: ctx.assigns.data_options
    }

    {:ok, payload, ctx}
  end

  @impl true
  def handle_info({:scan_binding_result, data_options, vl_alias}, ctx) do
    ctx = assign(ctx, data_options: data_options, vl_alias: vl_alias)

    first_layer = List.first(ctx.assigns.layers)

    updated_layer =
      case {first_layer["data_variable"], data_options} do
        {nil, [%{variable: data_variable} | _]} -> updates_for_data_variable(ctx, data_variable)
        _ -> %{}
      end

    ctx =
      if updated_layer == %{},
        do: ctx,
        else: update_in(ctx.assigns, fn assigns -> Map.put(assigns, :layers, [updated_layer]) end)

    broadcast_event(ctx, "set_available_data", %{
      "data_options" => data_options,
      "fields" => updated_layer
    })

    {:noreply, ctx}
  end

  @impl true
  def handle_event("update_field", %{"field" => field, "value" => value, "layer" => nil}, ctx) do
    parsed_value = parse_value(field, value)
    ctx = update(ctx, :root_fields, &Map.put(&1, field, parsed_value))
    broadcast_event(ctx, "update_root", %{"fields" => %{field => parsed_value}})

    {:noreply, ctx}
  end

  def handle_event(
        "update_field",
        %{"field" => "data_variable", "value" => value, "layer" => idx},
        ctx
      ) do
    updated_layer = updates_for_data_variable(ctx, value)
    updated_layers = List.replace_at(ctx.assigns.layers, idx, updated_layer)
    ctx = update_in(ctx.assigns, fn assigns -> Map.put(assigns, :layers, updated_layers) end)
    broadcast_event(ctx, "update_layer", %{"idx" => idx, "fields" => updated_layer})

    {:noreply, ctx}
  end

  def handle_event("update_field", %{"field" => field, "value" => value, "layer" => idx}, ctx) do
    parsed_value = parse_value(field, value)
    updated_layers = put_in(ctx.assigns.layers, [Access.at(idx), field], parsed_value)
    ctx = update_in(ctx.assigns, fn assigns -> Map.put(assigns, :layers, updated_layers) end)
    broadcast_event(ctx, "update_layer", %{"idx" => idx, "fields" => %{field => parsed_value}})

    {:noreply, ctx}
  end

  def handle_event("add_layer", _, ctx) do
    data_variable = List.first(ctx.assigns.layers)["data_variable"]
    new_layer = updates_for_data_variable(ctx, data_variable)
    updated_layers = ctx.assigns.layers ++ [new_layer]
    ctx = update_in(ctx.assigns, fn assigns -> Map.put(assigns, :layers, updated_layers) end)
    broadcast_event(ctx, "set_layers", %{"layers" => updated_layers})

    {:noreply, ctx}
  end

  def handle_event("remove_layer", %{"layer" => idx}, ctx) do
    updated_layers = List.delete_at(ctx.assigns.layers, idx)
    ctx = update_in(ctx.assigns, fn assigns -> Map.put(assigns, :layers, updated_layers) end)
    broadcast_event(ctx, "set_layers", %{"layers" => updated_layers})

    {:noreply, ctx}
  end

  defp updates_for_data_variable(ctx, value) do
    columns = Enum.find_value(ctx.assigns.data_options, [], &(&1.variable == value && &1.columns))

    {x_field, y_field} =
      case columns do
        [key] -> {key, key}
        [key1, key2 | _] -> {key1, key2}
        _ -> {nil, nil}
      end

    %{
      "chart_type" => "point",
      "data_variable" => value,
      "x_field" => x_field.name,
      "y_field" => y_field.name,
      "color_field" => nil,
      "x_field_type" => x_field.type,
      "y_field_type" => y_field.type,
      "color_field_type" => nil,
      "x_field_aggregate" => nil,
      "y_field_aggregate" => nil,
      "color_field_aggregate" => nil
    }
  end

  defp parse_value(_field, ""), do: nil
  defp parse_value(field, value) when field in @as_int, do: String.to_integer(value)
  defp parse_value(_field, value), do: value

  defp convert_field(field, nil), do: {String.to_atom(field), nil}

  defp convert_field(field, value) when field in @as_atom do
    {String.to_atom(field), String.to_atom(value)}
  end

  defp convert_field(field, value), do: {String.to_atom(field), value}

  defp vl_alias(%Macro.Env{aliases: aliases}) do
    case List.keyfind(aliases, VegaLite, 1) do
      {vl_alias, _} -> vl_alias
      nil -> VegaLite
    end
  end

  @impl true
  def to_attrs(ctx) do
    ctx.assigns.root_fields
    |> Map.put("layers", ctx.assigns.layers)
    |> Map.put("vl_alias", ctx.assigns.vl_alias)
  end

  @impl true
  def to_source(%{"layers" => [_layer]} = attrs) do
    attrs
    |> extract_layer()
    |> to_quoted()
    |> Kino.SmartCell.quoted_to_string()
  end

  def to_source(attrs) do
    attrs
    |> to_quoted()
    |> Kino.SmartCell.quoted_to_string()
  end

  defp to_quoted(%{"x_field" => nil, "y_field" => nil}) do
    quote do
    end
  end

  defp to_quoted(%{"layers" => layers} = attrs) do
    attrs =
      Map.take(attrs, ["chart_title", "width", "height", "vl_alias"])
      |> Map.new(fn {k, v} -> convert_field(k, v) end)

    root = %{
      field: nil,
      name: :new,
      module: attrs.vl_alias,
      args: build_arg_root(width: attrs.width, height: attrs.height, title: attrs.chart_title)
    }

    layer_root = %{
      "vl_alias" => attrs.vl_alias,
      "chart_title" => nil,
      "width" => nil,
      "height" => nil
    }

    root_data_variable = extract_root_data_variable(layers)

    layers =
      if root_data_variable,
        do: put_in(layers, [Access.all(), "data_variable"], nil),
        else: layers

    root =
      if root_data_variable,
        do: build_data_root(root, root_data_variable, layers, attrs.vl_alias),
        else: build_root(root)

    layers = for layer <- layers, do: to_quoted(Map.merge(layer_root, layer))
    apply_layers(root, layers, attrs.vl_alias)
  end

  defp to_quoted(attrs) do
    attrs = Map.new(attrs, fn {k, v} -> convert_field(k, v) end)

    [root | nodes] = [
      %{
        field: nil,
        name: :new,
        module: attrs.vl_alias,
        args: build_arg_root(width: attrs.width, height: attrs.height, title: attrs.chart_title)
      },
      %{
        field: :data,
        name: :data_from_values,
        module: attrs.vl_alias,
        args: build_arg_data(attrs.data_variable, used_fields(attrs))
      },
      %{field: :mark, name: :mark, module: attrs.vl_alias, args: [attrs.chart_type]},
      %{
        field: :x,
        name: encode(attrs.x_field),
        module: attrs.vl_alias,
        args: build_arg_field(attrs.x_field, attrs.x_field_type, attrs.x_field_aggregate)
      },
      %{
        field: :y,
        name: encode(attrs.y_field),
        module: attrs.vl_alias,
        args: build_arg_field(attrs.y_field, attrs.y_field_type, attrs.y_field_aggregate)
      },
      %{
        field: :color,
        name: encode(attrs.color_field),
        module: attrs.vl_alias,
        args:
          build_arg_field(attrs.color_field, attrs.color_field_type, attrs.color_field_aggregate)
      }
    ]

    root = build_root(root)
    Enum.reduce(nodes, root, &apply_node/2)
  end

  defp build_root(root) do
    quote do
      unquote(root.module).unquote(root.name)(unquote_splicing(root.args))
    end
  end

  defp build_data_root(root, variable, layers, vl_alias) do
    quote do
      unquote(build_root(root))
      |> unquote(vl_alias).unquote(:data_from_values)(
        unquote_splicing([Macro.var(variable, nil), [only: root_used_fields(layers)]])
      )
    end
  end

  defp apply_node(%{args: nil}, acc), do: acc

  defp apply_node(%{field: field, name: function, module: module, args: args}, acc) do
    args = if function in [:encode_field, :encode], do: [field | args], else: args

    quote do
      unquote(acc) |> unquote(module).unquote(function)(unquote_splicing(args))
    end
  end

  defp apply_layers(root, layers, vl_alias) do
    layers = Enum.reject(layers, &(&1 == {:__block__, [], []}))

    quote do
      unquote(root) |> unquote(vl_alias).layers(unquote(layers))
    end
  end

  defp build_arg_root(opts) do
    opts
    |> Enum.filter(&elem(&1, 1))
    |> case do
      [] -> []
      opts -> [opts]
    end
  end

  defp build_arg_data(nil, _), do: nil
  defp build_arg_data(variable, fields), do: [Macro.var(variable, nil), [only: fields]]

  defp build_arg_field(nil, _, _), do: nil
  defp build_arg_field(@count_field, _, _), do: [[aggregate: :count]]
  defp build_arg_field(field, nil, nil), do: [field]
  defp build_arg_field(field, type, nil), do: [field, [type: type]]
  defp build_arg_field(field, nil, aggregate), do: [field, [aggregate: aggregate]]
  defp build_arg_field(field, type, aggregate), do: [field, [type: type, aggregate: aggregate]]

  defp used_fields(attrs) do
    for attr <- [:x_field, :y_field, :color_field],
        value = attrs[attr],
        value not in [nil, @count_field],
        uniq: true,
        do: value
  end

  defp root_used_fields(layers) do
    for layer <- layers,
        attr <- ["x_field", "y_field", "color_field"],
        value = layer[attr],
        value not in [nil, @count_field],
        uniq: true,
        do: value
  end

  defp missing_dep() do
    unless Code.ensure_loaded?(VegaLite) do
      ~s/{:vega_lite, "~> 0.1.4"}/
    end
  end

  defp columns_for(data) do
    with true <- implements?(Table.Reader, data),
         data = {_, %{columns: columns}, _} <- Table.Reader.init(data),
         types <- infer_types(data),
         true <- Enum.all?(columns, &implements?(String.Chars, &1)) do
      Enum.zip_with(columns, types, fn column, type -> %{name: to_string(column), type: type} end)
    else
      _ -> nil
    end
  end

  defp implements?(protocol, value), do: protocol.impl_for(value) != nil

  defp encode(@count_field), do: :encode
  defp encode(_), do: :encode_field

  defp extract_layer(%{"layers" => [layer]} = attrs) do
    attrs
    |> Map.delete("layers")
    |> Map.merge(layer)
  end

  defp extract_root_data_variable(layers) do
    get_in(layers, [Access.all(), "data_variable"])
    |> Enum.dedup()
    |> case do
      [data_variable] -> String.to_atom(data_variable)
      _ -> nil
    end
  end

  defp infer_types({:columns, %{columns: _columns}, data}) do
    Enum.map(data, fn data -> Enum.to_list(data) |> List.first() |> type_of() end)
  end

  defp infer_types({:rows, %{columns: _columns}, data}) do
    Enum.to_list(data)
    |> List.first()
    |> Enum.map(&type_of/1)
  end

  defp type_of(data) when is_number(data), do: "quantitative"

  defp type_of(data) when is_binary(data) do
    if date?(Date.from_iso8601(data)) || date?(DateTime.from_iso8601(data)),
      do: "temporal",
      else: "nominal"
  end

  defp type_of(_), do: nil

  defp date?({:ok, _}), do: true
  defp date?({:error, _}), do: false
end
