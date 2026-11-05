defmodule MyLiege.Engine.SimSteps.DemandDelivery do
  @moduledoc "Step 10 of the week, R7 demand delivery: in a deadline week, delivers or refuses, or misses it."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.{Demands, Misses}

  @impl true
  def run(%{demand: %{due_week: week} = demand, week: week} = game, report) do
    {outcome, stocks} = Demands.settle(demand, game.stocks, game.deliver_demand)
    game = %{game | stocks: stocks, demand: nil, deliver_demand: nil}
    game = if outcome == :delivered, do: game, else: add_miss(game)
    {game, %{report | demand_outcome: outcome}}
  end

  def run(game, report), do: {game, report}

  defp add_miss(game) do
    {misses, over?} = Misses.add(game.misses, game.config)
    %{game | misses: misses, game_over: game.game_over or over?}
  end
end
