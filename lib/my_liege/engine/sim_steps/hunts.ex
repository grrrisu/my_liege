defmodule MyLiege.Engine.SimSteps.Hunts do
  @moduledoc """
  Step 8 of the week, after the inventions, R17 the hunting camp and R18 the king's suspicion:

  1. Each hunter who has arrived (travel 0 at the start of the week, as for production) fills
     the camp's bag; at every `way_hunting_haul_weeks`-th week with an arrived hunter there is
     a haul: one luck draw from `game.rand`, its food into the stock, and the suspicion changes
     by the haul (`Rules.Hunting.hunt/4`, `Rules.Suspicion.after_haul/4`).
  2. At the end of a block of `way_hunting_haul_weeks` game weeks in which no hunter had
     arrived, the suspicion decays.
  3. At the threshold the suspicion counts as one miss (R7) and is halved.

  The draw comes after the week's birth (step 6), at most once a week, and only in a haul
  week. The haul is in the stock for taxes, demands and spoilage of this week, not for its
  eating or birth.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Place
  alias MyLiege.Engine.Place.Expedition
  alias MyLiege.Engine.Rules.{Hunting, Misses, Suspicion, Travel}

  @impl true
  def run(game, report) do
    case Hunting.camp(game.places) do
      nil -> {game, report}
      camp -> run(game, report, camp)
    end
  end

  defp run(game, report, camp) do
    config = game.config
    workers = Travel.as_at_start(game.workers, report.start.workers)

    {camp, haul, rand} = Hunting.hunt(camp, workers, config, game.rand)
    {suspicion, haul} = after_haul(game.suspicion, haul, config)
    {camp, suspicion} = end_of_block(camp, suspicion, game.week, config)
    {suspicion, miss?} = Suspicion.check_threshold(suspicion, config)
    food = if haul, do: haul.food, else: 0

    game =
      %{
        game
        | places: Enum.map(game.places, &if(&1.id == camp.id, do: camp, else: &1)),
          stocks: %{game.stocks | food: game.stocks.food + food},
          suspicion: suspicion,
          rand: rand
      }
      |> add_miss(miss?)

    {game,
     %{
       report
       | hunters: game.workers |> Place.workers_at(camp.id) |> length(),
         haul: haul,
         food_from_hunting: food,
         suspicion_miss: miss?
     }}
  end

  defp after_haul(suspicion, nil, _config), do: {suspicion, nil}

  defp after_haul(suspicion, haul, config) do
    {suspicion, change} = Suspicion.after_haul(suspicion, haul.hunters, haul.luck, config)
    {suspicion, Map.put(haul, :suspicion_change, change)}
  end

  defp end_of_block(%Expedition{} = camp, suspicion, week, config) do
    cond do
      not Suspicion.block_end?(week, config) -> {camp, suspicion}
      camp.hunted_in_block -> {%{camp | hunted_in_block: false}, suspicion}
      true -> {camp, Suspicion.decay(suspicion, config)}
    end
  end

  defp add_miss(game, false), do: game

  defp add_miss(game, true) do
    {misses, over?} = Misses.add(game.misses, game.config)
    %{game | misses: misses, game_over: game.game_over or over?}
  end
end
