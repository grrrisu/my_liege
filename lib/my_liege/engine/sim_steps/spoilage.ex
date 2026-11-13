defmodule MyLiege.Engine.SimSteps.Spoilage do
  @moduledoc """
  Step 14 of the week, R9 spoilage: every stock above 0 loses its
  `good.<good>.spoilage_permille`; food the granary's rate if a granary worked this week (R14).
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.Spoilage

  @impl true
  def run(game, report) do
    {stocks, spoiled} = Spoilage.spoil(game.stocks, game.config, report.granary_working)
    {%{game | stocks: stocks}, %{report | spoiled: spoiled}}
  end
end
