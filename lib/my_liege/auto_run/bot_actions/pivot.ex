defmodule MyLiege.AutoRun.BotActions.Pivot do
  @moduledoc """
  Workers born from `from_week` on go to building type `to`. Workers already placed stay
  where they are. A placing action (`MyLiege.AutoRun.Placing`).

  Options: `to:` (a building type) and `from_week:`.
  """

  @behaviour MyLiege.AutoRun.BotAction
  @behaviour MyLiege.AutoRun.Placing

  alias MyLiege.AutoRun.Placing
  alias MyLiege.Engine.Game

  @impl MyLiege.AutoRun.BotAction
  def run(%Game{} = game, opts),
    do: Placing.run(game, Keyword.put(opts, :rules, [{__MODULE__, opts}]))

  @impl MyLiege.AutoRun.Placing
  def target(worker, _game, opts) do
    from_week = Keyword.fetch!(opts, :from_week)
    if worker.born_week != nil and worker.born_week >= from_week, do: Keyword.fetch!(opts, :to)
  end
end
