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
    "color_field_aggregate",
    "x_field_scale_type",
    "y_field_scale_type",
    "geodata_type",
    "projection_type"
  ]

  @count_field "__count__"
  @typed_fields ["x_field", "y_field", "color_field"]

  @impl true
  def init(attrs, ctx) do
    root_fields = %{
      "chart_title" => attrs["chart_title"],
      "width" => attrs["width"],
      "height" => attrs["height"]
    }

    layers =
      if attrs["layers"],
        do: Enum.map(attrs["layers"], &normalize_layer(&1)),
        else: [default_layer()]

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
    updated_layer = updates_for_layer(first_layer, data_options, ctx)

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
    ctx = assign(ctx, layers: updated_layers)
    broadcast_event(ctx, "update_layer", %{"idx" => idx, "fields" => updated_layer})

    {:noreply, ctx}
  end

  def handle_event("update_field", %{"field" => field, "value" => value, "layer" => idx}, ctx)
      when field in @typed_fields do
    {updated_fields, updated_layer} = updates_for_typed_fields(ctx, field, idx, value)
    updated_layers = List.replace_at(ctx.assigns.layers, idx, updated_layer)
    ctx = assign(ctx, layers: updated_layers)
    broadcast_event(ctx, "update_layer", %{"idx" => idx, "fields" => updated_fields})

    {:noreply, ctx}
  end

  def handle_event("update_field", %{"field" => field, "value" => value, "layer" => idx}, ctx) do
    parsed_value = parse_value(field, value)
    updated_layers = put_in(ctx.assigns.layers, [Access.at(idx), field], parsed_value)
    ctx = assign(ctx, layers: updated_layers)
    broadcast_event(ctx, "update_layer", %{"idx" => idx, "fields" => %{field => parsed_value}})

    {:noreply, ctx}
  end

  def handle_event("add_layer", _, ctx) do
    data_variable = List.first(ctx.assigns.layers)["data_variable"]
    new_layer = updates_for_data_variable(ctx, data_variable)
    updated_layers = ctx.assigns.layers ++ [new_layer]
    ctx = assign(ctx, layers: updated_layers)
    broadcast_event(ctx, "set_layers", %{"layers" => updated_layers})

    {:noreply, ctx}
  end

  def handle_event("add_geo_layer", _, ctx) do
    data_variable = List.first(ctx.assigns.layers)["data_variable"]
    geo_layer = default_geo_layer(data_variable)
    updated_layers = [geo_layer | ctx.assigns.layers]
    ctx = assign(ctx, layers: updated_layers)
    broadcast_event(ctx, "set_layers", %{"layers" => updated_layers})

    {:noreply, ctx}
  end

  def handle_event("remove_layer", %{"layer" => idx}, ctx) do
    updated_layers = List.delete_at(ctx.assigns.layers, idx)
    ctx = assign(ctx, layers: updated_layers)
    broadcast_event(ctx, "set_layers", %{"layers" => updated_layers})

    {:noreply, ctx}
  end

  defp updates_for_layer(%{"chart_type" => "geoshape"}, _, _), do: %{}

  defp updates_for_layer(first_layer, data_options, ctx) do
    case {first_layer["data_variable"], data_options} do
      {nil, [%{variable: data_variable} | _]} -> updates_for_data_variable(ctx, data_variable)
      _ -> %{}
    end
  end

  defp updates_for_data_variable(ctx, value) do
    columns = Enum.find_value(ctx.assigns.data_options, [], &(&1.variable == value && &1.columns))

    {x_field, y_field} =
      case columns do
        [key] -> {key, key}
        [key1, key2 | _] -> {key1, key2}
        _ -> {nil, nil}
      end

    layer = %{
      "data_variable" => value,
      "x_field" => x_field.name,
      "y_field" => y_field.name,
      "x_field_type" => x_field.type,
      "y_field_type" => y_field.type
    }

    Map.merge(default_layer(), layer)
  end

  defp updates_for_typed_fields(ctx, field, idx, value) do
    layer = Enum.at(ctx.assigns.layers, idx)

    columns =
      Enum.find_value(
        ctx.assigns.data_options,
        [],
        &(&1.variable == layer["data_variable"] && &1.columns)
      )

    type = Enum.find_value(columns, &(&1.name == value && &1.type))
    field_type = "#{field}_type"
    parsed_value = parse_value(field, value)
    parsed_type = parse_value(field_type, type)

    updated_fields = %{field => parsed_value, field_type => parsed_type}
    updated_layer = Map.merge(layer, updated_fields)

    {updated_fields, updated_layer}
  end

  defp parse_value(_field, ""), do: nil
  defp parse_value(field, value) when field in @as_int, do: String.to_integer(value)
  defp parse_value(_field, value), do: value

  defp convert_field(field, nil), do: {String.to_atom(field), nil}

  defp convert_field("projection_center", center) do
    Regex.named_captures(~r/(?<lng>-?\d+\.?\d*),\s*(?<lat>-?\d+\.?\d*)/, center)
    |> case do
      %{"lat" => lat, "lng" => lng} ->
        {{lng, _}, {lat, _}} = {Float.parse(lng), Float.parse(lat)}
        {:projection_center, validate_coords({lng, lat})}

      _ ->
        nil
    end
  end

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

  defp to_quoted(%{"geodata_url" => nil}) do
    quote do
    end
  end

  defp to_quoted(%{"geodata" => true, "latitude" => nil, "longitude" => nil}) do
    quote do
    end
  end

  defp to_quoted(%{"geodata" => false, "x_field" => nil, "y_field" => nil}) do
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

  defp to_quoted(%{"chart_type" => "geoshape"} = attrs) do
    attrs = Map.new(attrs, fn {k, v} -> convert_field(k, v) end)

    [root | nodes] = [
      %{
        field: nil,
        name: :new,
        module: attrs.vl_alias,
        args: build_arg_root(width: attrs.width, height: attrs.height, title: attrs.chart_title)
      },
      %{
        field: :geodata,
        name: :data_from_url,
        module: attrs.vl_alias,
        args: build_arg_geodata(attrs.geodata_url, attrs.geodata_type, attrs.geodata_feature)
      },
      %{
        field: :projection,
        name: :projection,
        module: attrs.vl_alias,
        args: build_arg_projection(type: attrs.projection_type, center: attrs.projection_center)
      },
      %{
        field: :mark,
        name: :mark,
        module: attrs.vl_alias,
        args: [attrs.chart_type, [fill: "lightgray", stroke: "white"]]
      }
    ]

    root = build_root(root)
    Enum.reduce(nodes, root, &apply_node/2)
  end

  defp to_quoted(%{"geodata" => true} = attrs) do
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
        args: build_arg_data(attrs.data_variable, [attrs.latitude_field, attrs.longitude_field])
      },
      %{field: :mark, name: :mark, module: attrs.vl_alias, args: [attrs.chart_type]},
      %{
        field: :latitude,
        name: encode(attrs.latitude_field),
        module: attrs.vl_alias,
        args: build_arg_field(attrs.latitude_field, [])
      },
      %{
        field: :longitude,
        name: encode(attrs.longitude_field),
        module: attrs.vl_alias,
        args: build_arg_field(attrs.longitude_field, [])
      }
    ]

    root = build_root(root)
    Enum.reduce(nodes, root, &apply_node/2)
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
        args:
          build_arg_field(attrs.x_field,
            type: attrs.x_field_type,
            aggregate: attrs.x_field_aggregate,
            bin: attrs.x_field_bin,
            scale: if(type = attrs.x_field_scale_type, do: [type: type])
          )
      },
      %{
        field: :y,
        name: encode(attrs.y_field),
        module: attrs.vl_alias,
        args:
          build_arg_field(attrs.y_field,
            type: attrs.y_field_type,
            aggregate: attrs.y_field_aggregate,
            bin: attrs.y_field_bin,
            scale: if(type = attrs.y_field_scale_type, do: [type: type])
          )
      },
      %{
        field: :color,
        name: encode(attrs.color_field),
        module: attrs.vl_alias,
        args:
          build_arg_field(attrs.color_field,
            type: attrs.color_field_type,
            aggregate: attrs.color_field_aggregate,
            bin: attrs.color_field_bin,
            scale: if(scheme = attrs.color_field_scale_scheme, do: [scheme: scheme])
          )
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

  defp build_arg_geodata(url, type, nil) do
    [url, [format: [type: type]]]
  end

  defp build_arg_geodata(url, type, feature) do
    [url, [format: [type: type, feature: feature]]]
  end

  defp build_arg_field(nil, _), do: nil
  defp build_arg_field(@count_field, _), do: [[aggregate: :count]]

  defp build_arg_field(field, opts) do
    args = for {_k, v} = opt <- opts, v, do: opt
    if args == [], do: [field], else: [field, args]
  end

  defp build_arg_projection(opts) do
    args = for {_k, v} = opt <- opts, v, do: opt
    if args != [], do: [args]
  end

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
         data = {_, %{columns: [_ | _] = columns}, _} <- Table.Reader.init(data),
         true <- Enum.all?(columns, &implements?(String.Chars, &1)) do
      types = infer_types(data)
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
    Enum.map(data, fn data -> data |> Enum.at(0) |> type_of() end)
  end

  defp infer_types({:rows, %{columns: columns}, data}) do
    case Enum.fetch(data, 0) do
      {:ok, row} -> Enum.map(row, &type_of/1)
      :error -> Enum.map(columns, fn _ -> nil end)
    end
  end

  defp type_of(%mod{}) when mod in [Decimal], do: "quantitative"
  defp type_of(%mod{}) when mod in [Date, NaiveDateTime, DateTime], do: "temporal"

  defp type_of(data) when is_number(data), do: "quantitative"

  defp type_of(data) when is_binary(data) do
    if date?(data) or date_time?(data), do: "temporal", else: "nominal"
  end

  defp type_of(data) when is_atom(data), do: "nominal"

  defp type_of(_), do: nil

  defp date?(value), do: match?({:ok, _}, Date.from_iso8601(value))
  defp date_time?(value), do: match?({:ok, _, _}, DateTime.from_iso8601(value))

  defp default_layer() do
    %{
      "chart_type" => "point",
      "data_variable" => nil,
      "geodata" => false,
      "x_field" => nil,
      "y_field" => nil,
      "color_field" => nil,
      "x_field_type" => nil,
      "y_field_type" => nil,
      "color_field_type" => nil,
      "x_field_aggregate" => nil,
      "y_field_aggregate" => nil,
      "color_field_aggregate" => nil,
      "x_field_bin" => false,
      "y_field_bin" => false,
      "color_field_bin" => false,
      "x_field_scale_type" => nil,
      "y_field_scale_type" => nil,
      "color_field_scale_scheme" => nil,
      "latitude_field" => nil,
      "longitude_field" => nil
    }
  end

  defp default_geo_layer(data_variable) do
    %{
      "geodata_url" => nil,
      "projection_center" => nil,
      "geodata_type" => "geojson",
      "projection_type" => "mercator",
      "geodata_feature" => nil,
      "chart_type" => "geoshape",
      "data_variable" => data_variable
    }
  end

  defp validate_coords({lng, lat}) do
    valid_lng? = lng >= -180 and lng <= 180
    valid_lat? = lat >= -90 and lat <= 90
    if valid_lng? and valid_lat?, do: [lng, lat]
  end

  defp normalize_layer(%{"chart_type" => "geoshape"} = layer), do: layer
  defp normalize_layer(layer), do: Map.merge(default_layer(), layer)
end
