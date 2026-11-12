defmodule MyLiege.Engine.Rules.Grace do
  @moduledoc """
  R7, grace period: in weeks 1 to `king_grace_weeks` the king collects no taxes and makes no
  demands. Everything else runs as usual.
  """

  alias MyLiege.Engine.Config

  @doc "Whether `week` lies inside the grace period."
  def in_grace?(week, %Config{} = config), do: week <= config.king_grace_weeks

  @doc "The last week of the grace period; 0 when there is none."
  def last_week(%Config{} = config), do: config.king_grace_weeks
end
