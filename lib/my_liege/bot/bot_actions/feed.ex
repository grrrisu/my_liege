defmodule MyLiege.Bot.BotActions.Feed do
  @moduledoc """
  While food is low (`food_low?/1`), unplaced workers go to a farm, whatever their colour.
  A placing action (`MyLiege.Bot.Placing`).
  """

  @behaviour MyLiege.Bot.BotAction
  @behaviour MyLiege.Bot.Placing

  alias MyLiege.Bot.Placing
  alias MyLiege.Engine.{Fixed, Forecast, Game}

  @impl MyLiege.Bot.BotAction
  def run(%Game{} = game, opts),
    do: Placing.run(game, Keyword.put(opts, :rules, [{__MODULE__, opts}]))

  @impl MyLiege.Bot.Placing
  def target(_worker, game, _opts), do: if(food_low?(game), do: :farm)

  @doc """
  Whether food is low: the food stock is below 0, or last week's food balance
  (`Forecast.food/1`: the change in the food stock in the last week) can't feed one more
  worker (< `good_food_eaten_per_worker`).
  """
  def food_low?(%Game{} = game) do
    one_more = Fixed.from(game.config.good_food_eaten_per_worker)

    case Forecast.food(game) do
      nil -> game.stocks.food < 0
      forecast -> game.stocks.food < 0 or forecast.change < one_more
    end
  end
end
