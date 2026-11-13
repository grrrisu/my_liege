defmodule MyLiege.Engine.SimSteps.ConstructionTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Game, WeeklyReport}
  alias MyLiege.Engine.SimSteps.Construction
  alias MyLiege.EngineFixtures

  # workers 1 and 2 are the builders of a market site
  setup do
    config = EngineFixtures.config(build_capacity: 2, travel_weeks: 1)
    {:ok, game} = config |> EngineFixtures.game_without_demands(1) |> Game.construct(:market)
    site = List.last(game.places)
    workers = Enum.map(game.workers, &%{&1 | place: site.id})
    %{game: %{game | workers: workers}, site: site}
  end

  test "builders travelling at the start of the week don't advance the site", context do
    %{game: game, site: site} = context
    start = %{game | workers: Enum.map(game.workers, &%{&1 | travel: 1})}
    # arrived by the time the step runs
    now = %{game | week: 1}

    {game, _report} = Construction.run(now, WeeklyReport.new(1, start))

    assert find(game, site.id).progress == 0
  end

  test "each builder arrived at the start of the week adds 1 to the site", context do
    %{game: game, site: site} = context

    {game, _report} = Construction.run(%{game | week: 1}, WeeklyReport.new(1, game))

    assert find(game, site.id).progress == 2
  end

  defp find(game, id), do: Enum.find(game.places, &(&1.id == id))
end
