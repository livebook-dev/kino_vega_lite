defmodule KinoVegaLite.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Kino.SmartCell.register(KinoVegaLite.ChartCell)

    children = []
    opts = [strategy: :one_for_one, name: KinoVegaLite.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
