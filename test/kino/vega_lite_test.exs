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

  test "signal/3 sends a signal event" do
    kino = start_kino()

    Kino.VegaLite.signal(kino, "signal_name", "value")

    assert_broadcast_event(kino, "signal", %{name: "signal_name", value: "value"})
  end

  test "clear/2 pushes empty data" do
    kino = start_kino()

    Kino.VegaLite.clear(kino)

    assert_broadcast_event(kino, "push", %{data: [], dataset: nil, window: 0})
  end

  test "periodically/4 evaluates the given callback in background until stopped" do
    kino = start_kino()

    parent = self()

    Kino.VegaLite.periodically(kino, 1, 1, fn n ->
      send(parent, {:ping, n})

      if n < 2 do
        {:cont, n + 1}
      else
        :halt
      end
    end)

    assert_receive {:ping, 1}
    assert_receive {:ping, 2}
    refute_receive {:ping, 3}, 5
  end

  defp start_kino() do
    Vl.new()
    |> Vl.mark(:point)
    |> Vl.encode_field(:x, "x", type: :quantitative)
    |> Vl.encode_field(:y, "y", type: :quantitative)
    |> Kino.VegaLite.new()
  end
end
