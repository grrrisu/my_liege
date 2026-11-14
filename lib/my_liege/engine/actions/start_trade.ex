defmodule MyLiege.Engine.Actions.StartTrade do
  @moduledoc """
  Starts a trade of `type` (R16), e.g. `:grain_trade`, with the worker `worker_id` as its
  trader: pays its gold from the stock at once (`Rules.Trades.cost/3`), appends the trade to
  the places and puts the trader on it, away from the next week (no travel of his own; a
  trainee loses his training). Returns `{:ok, game}`, or `{:error, reason}` with reason
  `:unknown_worker`, `:unknown_trade`, `:locked` (R13), `:away`, `:travelling` or
  `:not_enough_gold` (see `Rules.Trades.check_start/6`).
  """

  alias MyLiege.Engine.{Game, Place}
  alias MyLiege.Engine.Rules.Trades

  def run(%Game{} = game, worker_id, type) do
    with {:ok, worker} <- Game.fetch_worker(game, worker_id),
         place = Enum.find(game.places, &(&1.id == worker.place)),
         :ok <-
           Trades.check_start(type, worker, place, game.stocks.gold, game.books, game.config) do
      cost = Trades.cost(type, worker, game.config)
      places = Trades.new_trade(game.places, type, game.week, game.config)
      trader = %{worker | place: Place.next_id(game.places), travel: 0, training_started: nil}

      game = %{game | places: places, stocks: %{game.stocks | gold: game.stocks.gold - cost}}
      {:ok, Game.put_worker(game, trader)}
    end
  end
end
