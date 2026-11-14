defmodule MyLiege.Bot.BotActions.Defend do
  @moduledoc """
  While bandits are on their way, moves workers to finished watchtowers with room until
  the protected gold in the raid week (the watchtowers' expected defence production ×
  `bandit_cover_weeks`) covers the gold forecast for the raid week (the gold now plus last
  week's change for every week left), or no more workers can move. Only workers who arrive
  before the raid week count, so nobody moves once it is too late. Moved workers stay there
  after the raid.

  First the unplaced workers who have arrived, red ones first. Then workers taken from
  finished path buildings (not watchtowers, sites or the guildhouse): from the product with
  the largest stock change last week, as long as that change stays at 0 or more without the
  worker's output.
  """

  @behaviour MyLiege.Bot.BotAction

  alias MyLiege.Bot.Placing
  alias MyLiege.Engine.{Forecast, Game, Place}
  alias MyLiege.Engine.Place.{Blueprint, Building, Expedition, Project, Trade}
  alias MyLiege.Engine.Rules.{Bandits, Production, Travel}

  @impl true
  def run(%Game{} = game, _opts), do: defend(game)

  @doc "Moves workers to watchtowers as described in the moduledoc."
  def defend(%Game{} = game) do
    if Bandits.on_their_way?(game.bandits) and arrives_in_time?(game) do
      gold = raid_gold(game)
      defence = raid_defence(game)
      move_defenders(game, defence, gold, surplus(game))
    else
      game
    end
  end

  # a worker moved now travels `travel_weeks` and works from the week after
  defp arrives_in_time?(game),
    do: game.week + 1 + game.config.travel_weeks <= game.bandits.raid_week

  defp raid_gold(game) do
    change = with %{change: change} <- Forecast.gold(game), do: change
    game.stocks.gold + (change || 0) * (game.bandits.raid_week - game.week)
  end

  # defence produced in the raid week by workers already in watchtowers
  defp raid_defence(game) do
    raid_week = game.bandits.raid_week
    towers = game |> watchtowers() |> Map.new(&{&1.id, &1})

    game.workers
    |> Enum.filter(&(Map.has_key?(towers, &1.place) and game.week + 1 + &1.travel <= raid_week))
    |> Enum.sum_by(&Production.worker_output(&1, Map.fetch!(towers, &1.place), game.config))
  end

  defp watchtowers(game),
    do: for(%Building{} = place <- game.places, Place.type(place) == :watchtower, do: place)

  defp move_defenders(game, defence, gold, surplus) do
    with true <- Bandits.protected(defence, game.config) < gold,
         {worker, surplus} <- next_defender(game, surplus),
         {:ok, game, tower} <- place_in_tower(game, worker) do
      output = Production.worker_output(worker, tower, game.config)
      move_defenders(game, defence + output, gold, surplus)
    else
      _ -> game
    end
  end

  defp next_defender(game, surplus) do
    case game |> Placing.available() |> Enum.sort_by(&(&1.colour != :red)) do
      [worker | _] -> {worker, surplus}
      [] -> spare_worker(game, surplus)
    end
  end

  # a producing worker whose product keeps a change of 0 or more without it
  defp spare_worker(game, surplus) do
    places = Map.new(game.places, &{&1.id, &1})

    candidates =
      for worker <- game.workers,
          place = places[worker.place],
          place != nil,
          spare_building?(place),
          not Travel.travelling?(worker),
          product = Place.good(place),
          output = Production.worker_output(worker, place, game.config),
          Map.fetch!(surplus, product) - output >= 0,
          do: {worker, product, output}

    case Enum.max_by(candidates, fn {_, product, _} -> Map.fetch!(surplus, product) end, fn ->
           nil
         end) do
      nil -> nil
      {worker, product, output} -> {worker, Map.update!(surplus, product, &(&1 - output))}
    end
  end

  defp spare_building?(%Building{} = place),
    do: Place.type(place) not in [:watchtower, :guildhouse]

  defp spare_building?(%Project{}), do: false
  defp spare_building?(%Trade{}), do: false
  defp spare_building?(%Expedition{}), do: false

  defp surplus(%Game{report: %{stock_change: nil}}), do: Map.new(Blueprint.goods(), &{&1, 0})
  defp surplus(%Game{report: report}), do: report.stock_change

  defp place_in_tower(game, worker) do
    game
    |> watchtowers()
    |> Enum.find_value(fn tower ->
      case Game.place_worker(game, worker.id, tower.id) do
        {:ok, game} -> {:ok, game, tower}
        {:error, _} -> nil
      end
    end)
  end
end
