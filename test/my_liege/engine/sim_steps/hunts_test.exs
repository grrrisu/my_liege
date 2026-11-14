defmodule MyLiege.Engine.SimSteps.HuntsTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Place.{Blueprint, Expedition}
  alias MyLiege.Engine.SimSteps.Hunts
  alias MyLiege.Engine.WeeklyReport
  alias MyLiege.EngineFixtures

  # farm (1) with green worker 1, tower (2) with red worker 2; the camp (3) with worker 2;
  # always high luck
  setup do
    config =
      EngineFixtures.config(way_hunting_party: Map.new(1..4, &{&1, %{low: 0, mid: 0, high: 10}}))

    game = EngineFixtures.game_without_demands(config, 1)
    camp = %Expedition{id: 3, blueprint: Blueprint.fetch!(:hunting)}

    workers =
      Enum.map(game.workers, &if(&1.id == 2, do: %{&1 | place: 3, travel: 0}, else: &1))

    %{game: %{game | places: game.places ++ [camp], workers: workers}}
  end

  defp run(game, week, fields \\ []) do
    game = Map.merge(%{game | week: week}, Map.new(fields))
    Hunts.run(game, WeeklyReport.new(week, game))
  end

  defp camp(game), do: List.last(game.places)

  defp with_camp(game, fields),
    do: %{game | places: List.replace_at(game.places, -1, struct!(camp(game), fields))}

  test "a hunting week fills the bag, draws nothing", %{game: game} do
    {after_step, report} = run(game, 2)

    assert %Expedition{bag: 15_000, weeks: 1, hunted_in_block: true} = camp(after_step)
    assert after_step.rand == game.rand
    assert after_step.stocks.food == game.stocks.food
    assert report.haul == nil
    assert report.hunters == 1
  end

  test "the haul week: the food into the stock, one draw, the suspicion's change", %{game: game} do
    game = with_camp(game, bag: 75_000, weeks: 5)
    farmer = Enum.find(game.workers, &(&1.id == 1))
    game = %{game | workers: [%{farmer | place: 3} | tl(game.workers)]}

    {after_step, report} = run(game, 9, suspicion: 4)

    # 75 + 15 (red) + 7.5 (green) = 97.5, × 1.5
    assert report.haul == %{hunters: 2, luck: :high, food: 146_250, suspicion_change: 2}
    assert report.food_from_hunting == 146_250
    assert after_step.stocks.food == game.stocks.food + 146_250
    assert after_step.suspicion == 6
    assert after_step.rand != game.rand
    assert %Expedition{bag: 0, weeks: 0} = camp(after_step)
  end

  test "a lone hunter's haul lowers the suspicion", %{game: game} do
    {after_step, report} = run(with_camp(game, weeks: 5), 9, suspicion: 4)

    assert report.haul.suspicion_change == -1
    assert after_step.suspicion == 3
  end

  test "a hunter arrived only during the week (travel at its start) doesn't hunt", %{game: game} do
    game = %{game | week: 1}
    report = WeeklyReport.new(2, %{game | workers: Enum.map(game.workers, &%{&1 | travel: 1})})

    {after_step, _report} = Hunts.run(%{game | week: 2}, report)

    assert camp(after_step).bag == 0
  end

  test "a block of 6 game weeks without an arrived hunter: − decay at its end", %{game: game} do
    idle = %{game | workers: Enum.map(game.workers, &%{&1 | place: nil})}

    {after_step, _} = run(idle, 5, suspicion: 4)
    assert after_step.suspicion == 4

    {after_step, _} = run(idle, 6, suspicion: 4)
    assert after_step.suspicion == 4 - 1

    {after_step, _} = run(idle, 12, suspicion: 0)
    assert after_step.suspicion == 0
  end

  test "a block with a hunting week doesn't decay; the next block starts unhunted", %{
    game: game
  } do
    idle = %{game | workers: Enum.map(game.workers, &%{&1 | place: nil})}

    {after_step, _} = run(with_camp(idle, hunted_in_block: true), 6, suspicion: 4)

    assert after_step.suspicion == 4
    refute camp(after_step).hunted_in_block
  end

  test "the threshold counts a miss and halves the suspicion; a second miss ends the game",
       %{game: game} do
    game = with_camp(game, weeks: 5)
    farmer = Enum.find(game.workers, &(&1.id == 1))
    game = %{game | workers: [%{farmer | place: 3} | tl(game.workers)]}

    {after_step, report} = run(game, 9, suspicion: 11)

    # 11 + 2 = 13: a miss, then 6
    assert report.suspicion_miss
    assert after_step.suspicion == 6
    assert after_step.misses == 1
    refute after_step.game_over

    {after_step, _report} = run(game, 9, suspicion: 11, misses: 1)
    assert after_step.game_over
  end

  test "no camp: nothing happens", %{game: game} do
    game = %{game | places: Enum.drop(game.places, -1)}

    assert {^game, report} = Hunts.run(game, WeeklyReport.new(game.week, game))
    assert report.hunters == 0
  end
end
