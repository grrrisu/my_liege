defmodule MyLiege.Engine.SimSteps.Spoilage do
  @moduledoc """
  Step 15 of the week, R9 spoilage: every stock above 0 loses its
  `good.<good>.spoilage_permille`; the food the working granaries protect (R14, their number
  from step 1) spoils at the granary's rate instead.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.{Granary, Spoilage}

  @impl true
  def run(game, report) do
    protected = Granary.protected(report.granaries_working, game.stocks.food, game.config)
    {stocks, spoiled} = Spoilage.spoil(game.stocks, game.config, protected)
    {%{game | stocks: stocks}, %{report | spoiled: spoiled, food_protected: protected}}
  end
end
