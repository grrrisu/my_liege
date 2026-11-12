defmodule MyLiege.Engine.SimSteps.Spoilage do
  @moduledoc "Step 14 of the week, R9 spoilage: every stock above 0 loses its `good.<good>.spoilage_permille`."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.Spoilage

  @impl true
  def run(game, report) do
    {stocks, spoiled} = Spoilage.spoil(game.stocks, game.config)
    {%{game | stocks: stocks}, %{report | spoiled: spoiled}}
  end
end
