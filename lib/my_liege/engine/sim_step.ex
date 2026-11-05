defmodule MyLiege.Engine.SimStep do
  @moduledoc """
  One step of the weekly pipeline (see `MyLiege.Engine.Game.pipeline/0`).

  - `game` is the state now, after the earlier steps of the week.
  - `report.start` is the game as it was when the week began.
  - A step decides itself whether it applies this week; if not, it returns `{game, report}`
    unchanged.
  - Steps can't fail.
  """

  alias MyLiege.Engine.{Game, WeeklyReport}

  @callback run(Game.t(), WeeklyReport.t()) :: {Game.t(), WeeklyReport.t()}
end
