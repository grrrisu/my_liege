defmodule MyLiege.Engine.Actions.RefuseProject do
  @moduledoc """
  Refuses the open project at once: from the next week its product goes to the stock again,
  and that week's run settles it as refused, which counts as a miss. This is only possible
  when `Game.project_refusable?/1`; otherwise it returns `{:error, :no_project}`. Success
  returns `{:ok, game}` and the refusal takes effect in the next week.
  """

  alias MyLiege.Engine.Game

  def run(%Game{} = game) do
    if Game.project_refusable?(game),
      do: {:ok, %{game | deliver_demand: false}},
      else: {:error, :no_project}
  end
end
