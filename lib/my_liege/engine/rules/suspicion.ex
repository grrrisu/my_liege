defmodule MyLiege.Engine.Rules.Suspicion do
  @moduledoc """
  R18, the king's suspicion, counted only: every expedition that sets out (R17) adds
  `king_suspicion_per_expedition`. It has no effect yet.
  """

  alias MyLiege.Engine.Config

  @doc "No suspicion: the start of a game."
  def none, do: 0

  @doc "The suspicion after one more expedition sets out."
  def add_expedition(suspicion, %Config{} = config),
    do: suspicion + config.king_suspicion_per_expedition
end
