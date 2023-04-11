defmodule Kino.VegaLite do
  @moduledoc """
  A kino wrapping [VegaLite](https://hexdocs.pm/vega_lite) graphic.

  This kino allow for rendering regular VegaLite graphic and then
  streaming new data points to update the graphic.

  ## Examples

      chart =
        Vl.new(width: 400, height: 400)
        |> Vl.mark(:line)
        |> Vl.encode_field(:x, "x", type: :quantitative)
        |> Vl.encode_field(:y, "y", type: :quantitative)
        |> Kino.VegaLite.new()
        |> Kino.render()

      for i <- 1..300 do
        point = %{x: i / 10, y: :math.sin(i / 10)}
        Kino.VegaLite.push(chart, point)
        Process.sleep(25)
      end

  """

  use Kino.JS, assets_path: "lib/assets/vega_lite"
  use Kino.JS.Live

  @type t :: Kino.JS.Live.t()

  @doc """
  Creates a new kino with the given VegaLite definition.
  """
  @spec new(VegaLite.t()) :: t()
  def new(vl) when is_struct(vl, VegaLite) do
    Kino.JS.Live.new(__MODULE__, vl)
  end

  @doc false
  @spec static(VegaLite.t()) :: Kino.JS.t()
  def static(vl) when is_struct(vl, VegaLite) do
    data = %{
      spec: VegaLite.to_spec(vl),
      datasets: []
    }

    Kino.JS.new(__MODULE__, data, export_info_string: "vega-lite", export_key: :spec)
  end

  @doc """
  Appends a single data point to the graphic dataset.

  ## Options

    * `:window` - the maximum number of data points to keep.
      This option is useful when you are appending new
      data points to the plot over a long period of time

    * `dataset` - name of the targeted dataset from
      the VegaLite specification. Defaults to the default
      anonymous dataset

  """
  @spec push(t(), map(), keyword()) :: :ok
  def push(kino, data_point, opts \\ []) do
    dataset = opts[:dataset]
    window = opts[:window]

    data_point = Map.new(data_point)

    Kino.JS.Live.cast(kino, {:push, dataset, [data_point], window})
  end

  @doc """
  Appends a number of data points to the graphic dataset.

  See `push/3` for more details.
  """
  @spec push_many(t(), list(map()), keyword()) :: :ok
  def push_many(kino, data_points, opts \\ []) when is_list(data_points) do
    dataset = opts[:dataset]
    window = opts[:window]

    data_points = Enum.map(data_points, &Map.new/1)

    Kino.JS.Live.cast(kino, {:push, dataset, data_points, window})
  end

  @doc """
  Updates a vega-lite [parameter's](https://vega.github.io/vega-lite/docs/parameter.html#variable-parameters) value.

  The parameter must be registered: `VegaLite.param(vl, "param_name", opts)`.

  To use the parameter in the chart, set a property to `[expr: "param_name"]`.

  ## Examples

      chart =
        VegaLite.new(width: 400, height: 400)
        |> VegaLite.param("stroke_width", value: 3)
        |> VegaLite.mark(:line, stroke_width: [expr: "stroke_width"])
        |> VegaLite.encode_field(:x, "x", type: :quantitative)
        |> VegaLite.encode_field(:y, "y", type: :quantitative)
        |> Kino.VegaLite.new()
        |> Kino.render()

      Kino.VegaLite.set_param(chart, "stroke_width", 10)

  """
  @spec set_param(t(), String.t(), term()) :: :ok
  def set_param(kino, name, value) do
    Kino.JS.Live.cast(kino, {:set_param, name, value})
  end

  @doc """
  Removes all data points from the graphic dataset.

  ## Options

    * `dataset` - name of the targeted dataset from
      the VegaLite specification. Defaults to the default
      anonymous dataset

  """
  @spec clear(t(), keyword()) :: :ok
  def clear(kino, opts \\ []) do
    dataset = opts[:dataset]
    Kino.JS.Live.cast(kino, {:clear, dataset})
  end

  @doc """
  Registers a callback to run periodically in the kino process.

  The callback is run every `interval_ms` milliseconds and receives
  the accumulated value. The callback should return either of:

    * `{:cont, acc}` - the continue with the new accumulated value

    * `:halt` - to no longer schedule callback evaluation

  The callback is run for the first time immediately upon registration.
  """
  @spec periodically(t(), pos_integer(), term(), (term() -> {:cont, term()} | :halt)) :: :ok
  def periodically(kino, interval_ms, acc, fun) do
    Kino.JS.Live.cast(kino, {:periodically, interval_ms, acc, fun})
  end

  @impl true
  def init(vl, ctx) do
    {:ok, assign(ctx, vl: vl, datasets: %{})}
  end

  @compile {:no_warn_undefined, {VegaLite, :to_spec, 1}}

  @impl true
  def handle_connect(ctx) do
    data = %{
      spec: VegaLite.to_spec(ctx.assigns.vl),
      datasets: for({dataset, data} <- ctx.assigns.datasets, do: [dataset, data])
    }

    {:ok, data, ctx}
  end

  @impl true
  def handle_cast({:push, dataset, data, window}, ctx) do
    broadcast_event(ctx, "push", %{data: data, dataset: dataset, window: window})

    ctx =
      update(ctx, :datasets, fn datasets ->
        {current_data, datasets} = Map.pop(datasets, dataset, [])

        new_data =
          if window do
            Enum.take(current_data ++ data, -window)
          else
            current_data ++ data
          end

        Map.put(datasets, dataset, new_data)
      end)

    {:noreply, ctx}
  end

  def handle_cast({:clear, dataset}, ctx) do
    broadcast_event(ctx, "push", %{data: [], dataset: dataset, window: 0})
    ctx = update(ctx, :datasets, &Map.delete(&1, dataset))
    {:noreply, ctx}
  end

  def handle_cast({:set_param, name, value}, ctx) do
    broadcast_event(ctx, "set_param", %{name: name, value: value})
    {:noreply, ctx}
  end

  def handle_cast({:periodically, interval_ms, acc, fun}, state) do
    periodically_iter(interval_ms, acc, fun)
    {:noreply, state}
  end

  @impl true
  def handle_info({:periodically_iter, interval_ms, acc, fun}, ctx) do
    periodically_iter(interval_ms, acc, fun)
    {:noreply, ctx}
  end

  defp periodically_iter(interval_ms, acc, fun) do
    case fun.(acc) do
      {:cont, acc} ->
        Process.send_after(self(), {:periodically_iter, interval_ms, acc, fun}, interval_ms)

      :halt ->
        :ok
    end
  end
end
