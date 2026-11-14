defmodule MyLiege.Engine.Actions.Construct do
  @moduledoc """
  Orders a new building, which starts as a site (see `Rules.Construction`). Every type costs
  `build_cost_gold`, paid from the gold stock at once; the gold spent is added to
  `gold_spent_buildings` of the current week's report. There is no limit on number or
  frequency. A way (R13) can be ordered only once unlocked (`Rules.Ways`). A type that is not a
  building (`Blueprint.building_types/0`) returns `{:error, :unknown_type}`, a locked way
  `{:error, :locked}` and insufficient gold `{:error, :not_enough_gold}`, checked in this order.
  Success returns `{:ok, game}`; construction progresses starting next week.
  """

  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Place.Blueprint
  alias MyLiege.Engine.Rules.{Construction, Ways}

  def run(%Game{} = game, type) do
    cost = Game.build_cost(game)

    cond do
      type not in Blueprint.building_types() ->
        {:error, :unknown_type}

      not Ways.unlocked?(Blueprint.fetch!(type), game.books, game.inventions, game.config) ->
        {:error, :locked}

      not Game.can_afford_building?(game) ->
        {:error, :not_enough_gold}

      true ->
        report = %{game.report | gold_spent_buildings: game.report.gold_spent_buildings + cost}

        {:ok,
         %{
           game
           | places: Construction.new_site(game.places, type, game.config),
             stocks: %{game.stocks | gold: game.stocks.gold - cost},
             report: report
         }}
    end
  end
end
