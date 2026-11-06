defmodule MyLiege.Engine.SimSteps.DemandDelivery do
  @moduledoc """
  Step 10 of the week, R7 demand delivery: in a deadline week, delivers or refuses, or misses
  it. A project the player refused before this week is settled as refused now, whatever its
  deadline.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.{Demands, Misses}

  @impl true
  def run(%{demand: demand} = game, report) when demand != nil do
    if settle?(game) do
      deliver? = game.deliver_demand != false
      {outcome, stocks} = Demands.settle(demand, game.stocks, deliver?)
      game = %{game | stocks: stocks, demand: nil, deliver_demand: nil}
      game = if outcome == :delivered, do: game, else: add_miss(game)
      {game, %{report | demand_outcome: outcome}}
    else
      {game, report}
    end
  end

  def run(game, report), do: {game, report}

  defp settle?(game) do
    game.demand.due_week == game.week or
      (Demands.project?(game.demand) and game.deliver_demand == false)
  end

  defp add_miss(game) do
    {misses, over?} = Misses.add(game.misses, game.config)
    %{game | misses: misses, game_over: game.game_over or over?}
  end
end
