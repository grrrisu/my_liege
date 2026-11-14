defmodule MyLiege.Engine.Rules.Suspicion do
  @moduledoc """
  R18, the king's suspicion of the hunting camp (R17). Starts at 0, never below 0.

  - At a haul with 2 or more hunters it rises by `king_suspicion[luck]` (low, mid, high); at
    a haul with 1 hunter it falls by `king_suspicion_decay` (`after_haul/4`).
  - At the end of every block of `way_hunting_haul_weeks` game weeks (weeks 1 to 6, 7 to
    12, …) in which no hunter had arrived in the camp, it falls by `king_suspicion_decay`
    (`block_end?/2`, `decay/2`).
  - At `king_suspicion_threshold` or more it counts as one miss (R7) and is halved, rounded
    down (`check_threshold/2`). The king takes nothing for it.
  """

  alias MyLiege.Engine.Config

  @doc "No suspicion: the start of a game."
  def none, do: 0

  @doc """
  The suspicion after a haul by `hunters` at `luck`. Returns `{suspicion, change}`, `change`
  the difference actually made.
  """
  def after_haul(suspicion, hunters, luck, %Config{} = config) do
    new =
      if hunters == 1,
        do: decay(suspicion, config),
        else: suspicion + Map.fetch!(config.king_suspicion, luck)

    {new, new - suspicion}
  end

  @doc "The suspicion after one decay, not below 0."
  def decay(suspicion, %Config{} = config), do: max(suspicion - config.king_suspicion_decay, 0)

  @doc "Whether `week` ends a block of `way_hunting_haul_weeks` game weeks, counted from week 1."
  def block_end?(week, %Config{} = config), do: rem(week, config.way_hunting_haul_weeks) == 0

  @doc """
  At `king_suspicion_threshold` or more: `{half, true}` (half rounded down; the caller counts
  a miss); otherwise `{suspicion, false}`.
  """
  def check_threshold(suspicion, %Config{} = config) do
    if suspicion >= config.king_suspicion_threshold,
      do: {div(suspicion, 2), true},
      else: {suspicion, false}
  end
end
