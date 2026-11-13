defmodule MyLiege.AutoRun.Strategy do
  @moduledoc """
  A bot strategy: an ordered list of bot actions (`MyLiege.AutoRun.BotAction`), run before
  each week, and the build condition.

  - `actions`: `{module, opts}` or a bare module, Plug-style. Order is priority: the actions
    compete for the same workers, and an earlier action gets them first.
  - `build`: when an action that places workers may order a building: `:always`,
    `:tax_safe` (`Placing.tax_safe_to_build?/1`) or `:invest` (`Placing.invest_allowed?/3`).
  """

  @builds [:always, :tax_safe, :invest]

  @enforce_keys [:actions]
  defstruct actions: [], build: :always

  @type action :: module() | {module(), keyword()}
  @type t :: %__MODULE__{actions: [action()], build: :always | :tax_safe | :invest}

  @doc "A strategy from a list of actions; option `build:` (default `:always`)."
  def new(actions, opts \\ []) when is_list(actions) do
    build = Keyword.get(opts, :build, :always)
    true = build in @builds
    %__MODULE__{actions: actions, build: build}
  end

  @doc "The actions as `{module, opts}`."
  def actions(%__MODULE__{actions: actions}), do: Enum.map(actions, &normalize/1)

  defp normalize({module, opts}) when is_atom(module) and is_list(opts), do: {module, opts}
  defp normalize(module) when is_atom(module), do: {module, []}
end
