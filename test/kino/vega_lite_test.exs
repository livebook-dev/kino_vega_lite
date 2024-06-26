defmodule Kino.VegaLiteTest do
  use ExUnit.Case, async: true

  import Kino.Test

  alias VegaLite, as: Vl

  setup :configure_livebook_bridge

  test "sends current data after initial connection" do
    kino = start_kino()
    Kino.VegaLite.push(kino, %{x: 1, y: 1})

    data = connect(kino)
    assert %{spec: %{}, datasets: [[nil, [%{x: 1, y: 1}]]]} = data
  end

  test "does not send data outside of the specified window" do
    kino = start_kino()
    Kino.VegaLite.push(kino, %{x: 1, y: 1}, window: 1)
    Kino.VegaLite.push(kino, %{x: 2, y: 2}, window: 1)

    data = connect(kino)
    assert %{spec: %{}, datasets: [[nil, [%{x: 2, y: 2}]]]} = data
  end

  test "push/3 sends data point message to the client" do
    kino = start_kino()

    Kino.VegaLite.push(kino, %{x: 1, y: 1})

    assert_broadcast_event(kino, "push", %{data: [%{x: 1, y: 1}], dataset: nil, window: nil})
  end

  test "push/3 allows for specifying the dataset" do
    kino = start_kino()

    Kino.VegaLite.push(kino, %{x: 1, y: 1}, dataset: "points")

    assert_broadcast_event(kino, "push", %{
      data: [%{x: 1, y: 1}],
      dataset: "points",
      window: nil
    })
  end

  test "push/3 converts keyword list to map" do
    kino = start_kino()

    Kino.VegaLite.push(kino, x: 1, y: 1)

    assert_broadcast_event(kino, "push", %{data: [%{x: 1, y: 1}], dataset: nil, window: nil})
  end

  test "push/3 raises if an invalid data type is given" do
    kino = start_kino()

    assert_raise Protocol.UndefinedError, ~r/"invalid"/, fn ->
      Kino.VegaLite.push(kino, "invalid")
    end
  end

  test "push_many/3 sends multiple datapoints" do
    kino = start_kino()

    points = [%{x: 1, y: 1}, %{x: 2, y: 2}]
    Kino.VegaLite.push_many(kino, points)

    assert_broadcast_event(kino, "push", %{data: ^points, dataset: nil, window: nil})
  end

  test "push_many/3 raises if an invalid data type is given" do
    kino = start_kino()

    assert_raise Protocol.UndefinedError, ~r/"invalid"/, fn ->
      Kino.VegaLite.push_many(kino, ["invalid"])
    end
  end

  test "set_param/3 sends a set_param event" do
    kino = start_kino()

    Kino.VegaLite.set_param(kino, "param_name", "value")

    assert_broadcast_event(kino, "set_param", %{name: "param_name", value: "value"})
  end

  test "clear/2 pushes empty data" do
    kino = start_kino()

    Kino.VegaLite.clear(kino)

    assert_broadcast_event(kino, "push", %{data: [], dataset: nil, window: 0})
  end

  test "configure/2" do
    # with invalid theme
    assert_raise ArgumentError,
                 "expected :theme to be either :livebook or nil, got: :invalid",
                 fn -> Kino.VegaLite.configure(theme: :invalid) end

    # with default theme
    kino = start_kino()

    data = connect(kino)
    assert %{config: %{theme: :livebook}} = data

    # with empty theme
    Kino.VegaLite.configure(theme: nil)

    kino = start_kino()

    data = connect(kino)
    assert %{config: %{theme: nil}} = data
  end

  defp start_kino() do
    Vl.new()
    |> Vl.mark(:point)
    |> Vl.encode_field(:x, "x", type: :quantitative)
    |> Vl.encode_field(:y, "y", type: :quantitative)
    |> Kino.VegaLite.new()
  end
end
