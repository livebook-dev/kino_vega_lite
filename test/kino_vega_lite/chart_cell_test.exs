defmodule KinoVegaLite.ChartCellTest do
  use ExUnit.Case, async: true

  import Kino.Test

  alias KinoVegaLite.ChartCell

  setup :configure_livebook_bridge

  @root %{
    "width" => nil,
    "height" => nil,
    "chart_title" => nil,
    "vl_alias" => VegaLite
  }

  @layer %{
    "chart_type" => "bar",
    "data_variable" => "data",
    "geodata" => false,
    "x_field" => "a",
    "y_field" => "b",
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
    "longitude_field" => nil,
    "geodata_color" => "blue"
  }

  @geo_layer %{
    "geodata_url" => nil,
    "projection_center" => nil,
    "geodata_type" => "geojson",
    "projection_type" => "mercator",
    "geodata_feature" => nil,
    "chart_type" => "geoshape",
    "data_variable" => nil
  }

  test "returns no source when starting fresh with no data" do
    {_kino, source} = start_smart_cell!(ChartCell, %{})

    assert source == ""
  end

  test "finds tabular data in binding and sends new options to the client" do
    {kino, _source} = start_smart_cell!(ChartCell, %{})

    row_data = [%{x: 1, y: 1}, %{x: 2, y: 2}]
    column_data = %{x: 1..2, y: 1..2}
    temporal_data = %{x: ["cats", "dogs"], y: ["2022-01-01", "2020-01-01"]}
    invalid_data = %{self() => [1, 2], :y => [1, 2]}

    binding = [
      row_data: row_data,
      column_data: column_data,
      temporal_data: temporal_data,
      invalid_data: invalid_data
    ]

    # TODO: Use Code.env_for_eval on Elixir v1.14+
    env = :elixir.env_for_eval([])
    ChartCell.scan_binding(kino.pid, binding, env)

    data_options = [
      %{
        variable: "row_data",
        columns: [%{name: "x", type: "quantitative"}, %{name: "y", type: "quantitative"}]
      },
      %{
        variable: "column_data",
        columns: [%{name: "x", type: "quantitative"}, %{name: "y", type: "quantitative"}]
      },
      %{
        variable: "temporal_data",
        columns: [%{name: "x", type: "nominal"}, %{name: "y", type: "temporal"}]
      }
    ]

    assert_broadcast_event(kino, "set_available_data", %{
      "data_options" => ^data_options,
      "fields" => %{
        "data_variable" => "row_data",
        "x_field" => "x",
        "y_field" => "y",
        "x_field_type" => "quantitative",
        "y_field_type" => "quantitative"
      }
    })
  end

  describe "code generation" do
    test "source for a basic bar plot with no optionals" do
      attrs = build_attrs(%{})

      assert ChartCell.to_source(attrs) == """
             VegaLite.new()
             |> VegaLite.data_from_values(data, only: ["a", "b"])
             |> VegaLite.mark(:bar)
             |> VegaLite.encode_field(:x, "a")
             |> VegaLite.encode_field(:y, "b")\
             """
    end

    test "source for a basic line plot with alias" do
      attrs = build_attrs(%{"vl_alias" => Vl}, %{"chart_type" => "line"})

      assert ChartCell.to_source(attrs) == """
             Vl.new()
             |> Vl.data_from_values(data, only: ["a", "b"])
             |> Vl.mark(:line)
             |> Vl.encode_field(:x, "a")
             |> Vl.encode_field(:y, "b")\
             """
    end

    test "bar plot with color and color type" do
      attrs = build_attrs(%{"color_field" => "c", "color_field_type" => "nominal"})

      assert ChartCell.to_source(attrs) == """
             VegaLite.new()
             |> VegaLite.data_from_values(data, only: ["a", "b", "c"])
             |> VegaLite.mark(:bar)
             |> VegaLite.encode_field(:x, "a")
             |> VegaLite.encode_field(:y, "b")
             |> VegaLite.encode_field(:color, "c", type: :nominal)\
             """
    end

    test "point plot with width x and y field types and color without type" do
      attrs =
        build_attrs(%{"width" => 300}, %{
          "chart_type" => "point",
          "x_field_type" => "nominal",
          "y_field_type" => "quantitative",
          "color_field" => "c"
        })

      assert ChartCell.to_source(attrs) == """
             VegaLite.new(width: 300)
             |> VegaLite.data_from_values(data, only: ["a", "b", "c"])
             |> VegaLite.mark(:point)
             |> VegaLite.encode_field(:x, "a", type: :nominal)
             |> VegaLite.encode_field(:y, "b", type: :quantitative)
             |> VegaLite.encode_field(:color, "c")\
             """
    end

    test "area plot with types and alias" do
      attrs =
        build_attrs(
          %{"width" => 600, "height" => 300, "vl_alias" => Vl},
          %{
            "chart_type" => "point",
            "x_field_type" => "ordinal",
            "y_field_type" => "quantitative",
            "color_field" => "c",
            "color_field_type" => "nominal"
          }
        )

      assert ChartCell.to_source(attrs) == """
             Vl.new(width: 600, height: 300)
             |> Vl.data_from_values(data, only: ["a", "b", "c"])
             |> Vl.mark(:point)
             |> Vl.encode_field(:x, "a", type: :ordinal)
             |> Vl.encode_field(:y, "b", type: :quantitative)
             |> Vl.encode_field(:color, "c", type: :nominal)\
             """
    end

    test "area plot with aggregate and alias" do
      attrs =
        build_attrs(
          %{"width" => 600, "height" => 300, "vl_alias" => Vl},
          %{
            "chart_type" => "point",
            "x_field_type" => "ordinal",
            "y_field_aggregate" => "mean",
            "color_field" => "c",
            "color_field_type" => "nominal"
          }
        )

      assert ChartCell.to_source(attrs) == """
             Vl.new(width: 600, height: 300)
             |> Vl.data_from_values(data, only: ["a", "b", "c"])
             |> Vl.mark(:point)
             |> Vl.encode_field(:x, "a", type: :ordinal)
             |> Vl.encode_field(:y, "b", aggregate: :mean)
             |> Vl.encode_field(:color, "c", type: :nominal)\
             """
    end

    test "simple plot with title" do
      attrs = build_attrs(%{"chart_title" => "Chart Title"}, %{"chart_type" => "point"})

      assert ChartCell.to_source(attrs) == """
             VegaLite.new(title: "Chart Title")
             |> VegaLite.data_from_values(data, only: ["a", "b"])
             |> VegaLite.mark(:point)
             |> VegaLite.encode_field(:x, "a")
             |> VegaLite.encode_field(:y, "b")\
             """
    end

    test "simple plot with aggregate count" do
      attrs = build_attrs(%{"y_field" => "__count__"})

      assert ChartCell.to_source(attrs) == """
             VegaLite.new()
             |> VegaLite.data_from_values(data, only: ["a"])
             |> VegaLite.mark(:bar)
             |> VegaLite.encode_field(:x, "a")
             |> VegaLite.encode(:y, aggregate: :count)\
             """
    end

    test "simple plot with bin" do
      attrs = build_attrs(%{"x_field_bin" => true, "y_field" => "__count__"})

      assert ChartCell.to_source(attrs) == """
             VegaLite.new()
             |> VegaLite.data_from_values(data, only: ["a"])
             |> VegaLite.mark(:bar)
             |> VegaLite.encode_field(:x, "a", bin: true)
             |> VegaLite.encode(:y, aggregate: :count)\
             """
    end
  end

  describe "code generation for scales" do
    test "plot with linear scale for x" do
      attrs =
        build_attrs(%{
          "x_field_type" => "quantitative",
          "x_field_scale_type" => "log",
          "y_field" => "__count__"
        })

      assert ChartCell.to_source(attrs) == """
             VegaLite.new()
             |> VegaLite.data_from_values(data, only: ["a"])
             |> VegaLite.mark(:bar)
             |> VegaLite.encode_field(:x, "a", type: :quantitative, scale: [type: :log])
             |> VegaLite.encode(:y, aggregate: :count)\
             """
    end

    test "plot with color scheme" do
      attrs =
        build_attrs(%{
          "y_field" => "__count__",
          "color_field" => "c",
          "color_field_scale_scheme" => "accent"
        })

      assert ChartCell.to_source(attrs) == """
             VegaLite.new()
             |> VegaLite.data_from_values(data, only: ["a", "c"])
             |> VegaLite.mark(:bar)
             |> VegaLite.encode_field(:x, "a")
             |> VegaLite.encode(:y, aggregate: :count)
             |> VegaLite.encode_field(:color, "c", scale: [scheme: "accent"])\
             """
    end
  end

  describe "code generation for layers" do
    test "two layers with same data" do
      attrs =
        build_layers_attrs(%{
          "x_field" => nil,
          "y_field" => "c",
          "chart_type" => "rule",
          "color_field" => "__count__"
        })

      assert ChartCell.to_source(attrs) == """
             VegaLite.new()
             |> VegaLite.data_from_values(data, only: ["a", "b", "c"])
             |> VegaLite.layers([
               VegaLite.new()
               |> VegaLite.mark(:bar)
               |> VegaLite.encode_field(:x, "a")
               |> VegaLite.encode_field(:y, "b"),
               VegaLite.new()
               |> VegaLite.mark(:rule)
               |> VegaLite.encode_field(:y, "c")
               |> VegaLite.encode(:color, aggregate: :count)
             ])\
             """
    end

    test "two layers with different data" do
      attrs = build_layers_attrs(%{"data_variable" => "cats", "x_field" => "c", "y_field" => "d"})

      assert ChartCell.to_source(attrs) == """
             VegaLite.new()
             |> VegaLite.layers([
               VegaLite.new()
               |> VegaLite.data_from_values(data, only: ["a", "b"])
               |> VegaLite.mark(:bar)
               |> VegaLite.encode_field(:x, "a")
               |> VegaLite.encode_field(:y, "b"),
               VegaLite.new()
               |> VegaLite.data_from_values(cats, only: ["c", "d"])
               |> VegaLite.mark(:bar)
               |> VegaLite.encode_field(:x, "c")
               |> VegaLite.encode_field(:y, "d")
             ])\
             """
    end

    test "do not generate code for empty layers" do
      attrs = build_layers_attrs(%{"x_field" => nil, "y_field" => nil})

      assert ChartCell.to_source(attrs) == """
             VegaLite.new()
             |> VegaLite.data_from_values(data, only: ["a", "b"])
             |> VegaLite.layers([
               VegaLite.new()
               |> VegaLite.mark(:bar)
               |> VegaLite.encode_field(:x, "a")
               |> VegaLite.encode_field(:y, "b")
             ])\
             """
    end
  end

  describe "code generation for geodata" do
    test "geodata from url" do
      geo_layer = %{
        "geodata_url" =>
          "https://raw.githubusercontent.com/deldersveld/topojson/master/countries/germany/germany-regions.json",
        "geodata_feature" => "DEU_adm2",
        "geodata_type" => "topojson"
      }

      layer = %{
        "geodata" => true,
        "latitude_field" => "latitude",
        "longitude_field" => "longitude",
        "chart_type" => "point"
      }

      attrs = build_geo_layer_attrs([geo_layer, layer])

      assert ChartCell.to_source(attrs) == """
             VegaLite.new()
             |> VegaLite.layers([
               VegaLite.new()
               |> VegaLite.data_from_url(
                 "https://raw.githubusercontent.com/deldersveld/topojson/master/countries/germany/germany-regions.json",
                 format: [type: :topojson, feature: "DEU_adm2"]
               )
               |> VegaLite.projection(type: :mercator)
               |> VegaLite.mark(:geoshape, fill: "lightgray", stroke: "white"),
               VegaLite.new()
               |> VegaLite.data_from_values(data, only: ["latitude", "longitude"])
               |> VegaLite.mark(:point, color: "blue")
               |> VegaLite.encode_field(:latitude, "latitude")
               |> VegaLite.encode_field(:longitude, "longitude")
             ])\
             """
    end
  end

  defp build_attrs(root_attrs \\ %{}, layer_attrs) do
    root_attrs = Map.merge(@root, root_attrs)
    layer_attrs = Map.merge(@layer, layer_attrs)
    Map.put(root_attrs, "layers", [layer_attrs])
  end

  defp build_layers_attrs(root_attrs \\ %{}, layer_attrs) do
    root_attrs = Map.merge(@root, root_attrs)
    layer_attrs = Map.merge(@layer, layer_attrs)
    Map.put(root_attrs, "layers", [@layer, layer_attrs])
  end

  defp build_geo_layer_attrs(root_attrs \\ %{}, [geo_layer_attrs, layer_attrs]) do
    root_attrs = Map.merge(@root, root_attrs)
    geo_layer_attrs = Map.merge(@geo_layer, geo_layer_attrs)
    layer_attrs = Map.merge(@layer, layer_attrs)
    Map.put(root_attrs, "layers", [geo_layer_attrs, layer_attrs])
  end
end
