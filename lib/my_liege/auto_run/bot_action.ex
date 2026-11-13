defmodule MyLiege.AutoRun.BotAction do
  @moduledoc """
  One thing the bot takes care of between two weeks, e.g. staffing sites or paying the tax.

  Bot actions are player decisions, not game rules. They change the game only through
  `MyLiege.Engine.Game`; to decide they may read `Rules.*` and `Forecast`.

  `run/2` receives the action's own opts merged with the strategy's `build:` and the run
  options (`pivot_week:`, `weeks:`). Actions that place workers also implement
  `MyLiege.AutoRun.Placing` (see there).

  Named `BotAction` to keep them apart from the engine's player actions.
  """

  alias MyLiege.Engine.Game

  @callback run(Game.t(), opts :: keyword()) :: Game.t()
end
