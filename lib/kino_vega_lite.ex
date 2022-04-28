defimpl Kino.Render, for: VegaLite do
  def to_livebook(vl) do
    vl |> Kino.VegaLite.static() |> Kino.Render.to_livebook()
  end
end
