defmodule MyLiege.Bot.Placing do
  @moduledoc """
  The shared helper for every bot action that places workers.

  A placing action implements `target/3`: where it sends a worker, or `nil` if it leaves the
  worker to the next action. A target is either
  - a building type (e.g. `:farm`): a building of that type with room, or a site that gives
    one, as below; or
  - `{:place, place_id}`: that one place (e.g. a king's demand project). The worker goes
    there if `Game.place_worker/3` allows it (`Rules.Placement.check_enter/3`); otherwise it
    stays unplaced. No building is ordered for such a target.

  Its `run/2` is `Placing.run(game, opts)` with `rules: [{__MODULE__, opts}]`.

  `run/2` takes the arrived unplaced workers in worker order. For each, the first rule that
  names a target gets the worker. For a type it goes to a finished building of that type with room, or a
  site that gives one (as a builder). If there is none, the worker waits unplaced; a new
  building is ordered only when the sites already under construction can't take all
  workers waiting for that type, and only if the strategy's build condition allows it
  (`may_build?/4`) and `Game.construct/2` succeeds (the gold covers `build_cost_gold`).

  Before the pass, every rule that implements the optional `before_pass/2` runs it, in rule
  order, without placing workers (e.g. `WriteBooks` starts books there). After the pass,
  every rule that implements the optional `after_pass/2` runs it, in rule order (e.g.
  `DemandProject` moves workers out of buildings there). `left_over?/3` tells a rule whether
  the rules before it leave a worker alone.

  The runner runs consecutive placing actions of a strategy as one pass (`group/1`), so an
  earlier action gets each worker first and the workers waiting for a type are counted
  together, whichever action sent them.
  """

  alias MyLiege.Bot.BotActions.Feed
  alias MyLiege.Engine.{Forecast, Game, Place, Worker}
  alias MyLiege.Engine.Place.{Blueprint, Building, Expedition, Project, Trade}
  alias MyLiege.Engine.Rules.{Production, Travel}

  @behaviour MyLiege.Bot.BotAction

  @type target :: atom() | {:place, pos_integer()}

  @callback target(Worker.t(), Game.t(), opts :: keyword()) :: target() | nil

  @doc """
  Optional: what the action does before the pass, without placing workers, e.g. starting
  books (`WriteBooks`). Runs once per pass, in rule order.
  """
  @callback before_pass(Game.t(), opts :: keyword()) :: Game.t()

  @doc """
  Optional: what the action does after the pass, e.g. moving placed workers
  (`DemandProject`). Runs once per pass, in rule order.
  """
  @callback after_pass(Game.t(), opts :: keyword()) :: Game.t()

  @optional_callbacks before_pass: 2, after_pass: 2

  @doc """
  Places the available workers by `rules` (`[{module, opts}]`, in priority order) under the
  build condition `build`. Before the pass each rule's `before_pass/2` runs, after it each
  rule's `after_pass/2`, if it has one. Each rule's opts also get `earlier:`, the rules
  before it (see `left_over?/3`).
  """
  @impl MyLiege.Bot.BotAction
  def run(%Game{} = game, opts) do
    rules = opts |> Keyword.fetch!(:rules) |> with_earlier()
    build = Keyword.fetch!(opts, :build)

    game =
      Enum.reduce(rules, game, fn {module, opts}, game ->
        hook(module, :before_pass, game, opts)
      end)

    {game, _waiting} =
      game
      |> available()
      |> Enum.reduce({game, %{}}, fn worker, {game, waiting} ->
        case target(rules, worker, game) do
          nil -> {game, waiting}
          {:place, place_id} -> {place_on(game, worker, place_id), waiting}
          type -> place_or_wait(game, worker, type, waiting, build)
        end
      end)

    Enum.reduce(rules, game, fn {module, opts}, game -> hook(module, :after_pass, game, opts) end)
  end

  @doc """
  Whether the rules before this one in the pass (`opts[:earlier]`) leave `worker` alone: none
  of them names a target for it.
  """
  def left_over?(worker, %Game{} = game, opts) do
    opts
    |> Keyword.get(:earlier, [])
    |> Enum.all?(fn {module, earlier_opts} ->
      module.target(worker, game, earlier_opts) == nil
    end)
  end

  defp with_earlier(rules) do
    rules
    |> Enum.with_index()
    |> Enum.map(fn {{module, opts}, index} ->
      {module, Keyword.put(opts, :earlier, Enum.take(rules, index))}
    end)
  end

  # a module not loaded yet would not show its functions to `function_exported?/3`
  defp hook(module, name, game, opts) do
    Code.ensure_loaded!(module)
    if function_exported?(module, name, 2), do: apply(module, name, [game, opts]), else: game
  end

  @doc "Whether `module` is a placing action (implements `target/3`)."
  def placing?(module) do
    Code.ensure_loaded!(module)
    function_exported?(module, :target, 3)
  end

  @doc """
  Merges each run of consecutive placing actions in `actions` (`[{module, opts}]`, opts
  already merged) into one `{Placing, rules: [...], build: build}` step.
  """
  def group(actions) do
    actions
    |> Enum.chunk_by(fn {module, _opts} -> placing?(module) end)
    |> Enum.flat_map(fn [{first, opts} | _] = chunk ->
      if placing?(first),
        do: [{__MODULE__, rules: chunk, build: Keyword.fetch!(opts, :build)}],
        else: chunk
    end)
  end

  @doc "Unplaced workers who have arrived and can be placed, in worker order."
  def available(%Game{} = game),
    do: Enum.filter(game.workers, &(is_nil(&1.place) and not Travel.travelling?(&1)))

  @doc """
  Whether the build condition allows ordering a building of `type` now for the `waiting`
  workers: `:always`, `:tax_safe` (`tax_safe_to_build?/1`) or `:invest`
  (`invest_allowed?/3`).
  """
  def may_build?(:always, _game, _type, _waiting), do: true
  def may_build?(:tax_safe, game, _type, _waiting), do: tax_safe_to_build?(game)
  def may_build?(:invest, game, type, waiting), do: invest_allowed?(game, type, waiting)

  @doc """
  "Feed, save for tax": whether a building may be ordered now. Not after a week in which gold
  left the stock other than by spoilage (tax, the king's takings, a delivered demand,
  robbery), because that week's change would distort the forecast. Otherwise only if the
  forecast gold for the next tax week (`Forecast.next_tax/1`; in week 0, which has no
  forecast, the gold now) minus the building's price still covers the tax. With no tax left
  in the game, always.
  """
  def tax_safe_to_build?(%Game{} = game) do
    not gold_left_last_week?(game) and covers_next_tax?(game)
  end

  defp gold_left_last_week?(%Game{report: %{stock_change: nil}}), do: false

  defp gold_left_last_week?(%Game{report: report}),
    do: report.production.gold - report.spoiled.gold - report.stock_change.gold > 0

  defp covers_next_tax?(game) do
    case Forecast.next_tax(game) do
      nil ->
        true

      %{amount: amount, expected_gold: expected} ->
        (expected || game.stocks.gold) - Game.build_cost(game) >= amount
    end
  end

  @doc """
  "Feed, invest and defend": whether a building of `type` may be ordered now for the
  `waiting` workers. A farm always while food is low (as in `:feed`). Otherwise only if the
  forecast gold for the next tax week (`Forecast.next_tax/1`; in week 0 the gold now) minus
  the price plus what the building is expected to earn until that week still covers the tax.
  Only a market earns gold: from its first producing week, ordered now + 1 + 2 ×
  `travel_weeks` (builders, then workers) + the weeks with full builders
  (`build_work` ÷ `build_capacity`, rounded up), to the tax week, with the
  waiting workers up to its capacity. With no tax left in the game, always.
  """
  def invest_allowed?(%Game{} = game, type, waiting) do
    if type == :farm and Feed.food_low?(game) do
      true
    else
      case Forecast.next_tax(game) do
        nil ->
          true

        %{amount: amount, expected_gold: expected, due_week: due_week} ->
          gold = (expected || game.stocks.gold) - Game.build_cost(game)
          gold + earnings(game, type, waiting, due_week) >= amount
      end
    end
  end

  defp earnings(game, :market, waiting, due_week) do
    config = game.config
    weeks_to_build = div(config.build_work + config.build_capacity - 1, config.build_capacity)
    first_week = game.week + 1 + 2 * config.travel_weeks + weeks_to_build
    market = %Building{id: 0, blueprint: Blueprint.fetch!(:market)}

    per_week =
      waiting
      |> Enum.take(Map.fetch!(config.place_capacity, :market))
      |> Enum.sum_by(&Production.worker_output(&1, market, config))

    per_week * max(due_week - first_week + 1, 0)
  end

  defp earnings(_game, _type, _waiting, _due_week), do: 0

  defp target(rules, worker, game),
    do: Enum.find_value(rules, fn {module, opts} -> module.target(worker, game, opts) end)

  defp place_on(game, worker, place_id) do
    case Game.place_worker(game, worker.id, place_id) do
      {:ok, game} -> game
      {:error, _reason} -> game
    end
  end

  defp place_or_wait(game, worker, type, waiting, build) do
    case place_in_any(game, worker, type) do
      {:ok, game} ->
        {game, waiting}

      :none ->
        waiting = Map.update(waiting, type, [worker], &(&1 ++ [worker]))
        {order_if_needed(game, type, Map.fetch!(waiting, type), build), waiting}
    end
  end

  defp place_in_any(game, worker, type) do
    game.places
    |> Enum.filter(&(builds(&1) == type))
    |> Enum.find_value(:none, fn place ->
      case Game.place_worker(game, worker.id, place.id) do
        {:ok, game} -> {:ok, game}
        {:error, _} -> nil
      end
    end)
  end

  defp order_if_needed(game, type, waiting, build) do
    sites = Enum.count(game.places, &match?(%Project{gives: {:building, ^type}}, &1))
    room_under_construction = sites * Map.fetch!(game.config.place_capacity, type)

    with true <- length(waiting) > room_under_construction,
         true <- may_build?(build, game, type, waiting),
         {:ok, game} <- Game.construct(game, type) do
      game
    else
      _ -> game
    end
  end

  # the type of a building, or of the building a site gives; a waiting worker may also be
  # placed on a site of its type, as a builder. A king's demand project is no type: only a
  # `{:place, id}` target (`DemandProject`) sends workers there.
  defp builds(%Building{} = building), do: Place.type(building)
  defp builds(%Project{gives: {:building, type}}), do: type
  defp builds(%Project{gives: {:demand, _}}), do: nil
  # nor on a book (R12): the bots start no books
  defp builds(%Project{gives: {:book, _}}), do: nil
  # nor on an invention (R15), a trade route (R16) or a hunt (R17): the bots use no ways
  defp builds(%Project{gives: {:invention, _}}), do: nil
  defp builds(%Trade{}), do: nil
  defp builds(%Expedition{}), do: nil
end
