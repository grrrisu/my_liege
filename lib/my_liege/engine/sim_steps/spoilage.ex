defmodule MyLiege.Engine.SimSteps.Spoilage do
  @moduledoc "Spoilage: every stock above 0 loses its `spoilage_rate_<product>`."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Spoilage

  @impl true
  def run(game, report) do
    {stocks, spoiled} = Spoilage.spoil(game.stocks, game.config)
    {%{game | stocks: stocks}, %{report | spoiled: spoiled}}
  end
end
