defmodule MyLiege.Engine.Actions.Construct do
  @moduledoc """
  Orders a new building, which starts as a site (see `Rules.Construction`). Every type costs
  `build_cost_gold`, paid from the gold stock at once; the gold spent is added to
  `gold_spent_buildings` of the current week's report. There is no limit on number or
  frequency. An unknown type returns
  `{:error, :unknown_type}` and insufficient gold returns `{:error, :not_enough_gold}`.
  Success returns `{:ok, game}`; construction progresses starting next week.
  """

  alias MyLiege.Engine.{Building, Game}

  def run(%Game{} = game, type) do
    cost = Game.build_cost(game)

    cond do
      type not in Building.types() ->
        {:error, :unknown_type}

      not Game.can_afford_building?(game) ->
        {:error, :not_enough_gold}

      true ->
        report = %{game.report | gold_spent_buildings: game.report.gold_spent_buildings + cost}

        {:ok,
         %{
           game
           | buildings: Building.construct(game.buildings, type),
             stocks: %{game.stocks | gold: game.stocks.gold - cost},
             report: report
         }}
    end
  end
end
