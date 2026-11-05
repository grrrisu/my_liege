defmodule MyLiege.Engine.SimSteps.DemandDelivery do
  @moduledoc "Demand delivery (R7), deadline weeks only: delivers or refuses, or misses it."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.{Demands, Misses}

  @impl true
  def run(%{demand: %{due_week: week} = demand, week: week} = game, report) do
    {outcome, stocks} = Demands.settle(demand, game.stocks, game.deliver_demand)
    game = %{game | stocks: stocks, demand: nil, deliver_demand: nil}
    game = if outcome == :delivered, do: game, else: Misses.record(game)
    {game, %{report | demand_outcome: outcome}}
  end

  def run(game, report), do: {game, report}
end
