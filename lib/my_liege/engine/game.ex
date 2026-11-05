defmodule MyLiege.Engine.Game do
  @moduledoc """
  The state of one run and the weekly step. `week` is the last week run: 0 is the starting
  state from the config, and the first week that changes anything is week 1.

  Each week runs in this order: production (and its mana), travel, Manameter update, eating,
  birth, construction, training, taxes, demands, spoilage. The village is counted for taxes at the start of a count week, before its birth.
  Stocks are in thousandths (see `Fixed`).
  """

  alias MyLiege.Engine.{
    Births,
    Building,
    Config,
    Construction,
    Demands,
    Fixed,
    Food,
    Mana,
    Manameter,
    ManameterUpdate,
    Production,
    Random,
    Spoilage,
    Taxes,
    Training,
    Travel,
    WeeklyReport,
    Worker
  }

  @derive {Inspect, except: [:config]}
  @enforce_keys [
    :config,
    :seed,
    :rand,
    :week,
    :workers,
    :buildings,
    :manameter,
    :stocks,
    :report,
    :demand_weeks
  ]
  defstruct @enforce_keys ++
              [
                tax_due: nil,
                pay_tax: nil,
                demand: nil,
                deliver_demand: nil,
                misses: 0,
                game_over: false
              ]

  # fixed by the designer, not read from the CSV
  @weeks_per_year 48

  def weeks_per_year, do: @weeks_per_year

  @doc "The last week of the game: the end of year `years_per_game` of the game's config."
  def last_week(%__MODULE__{config: config}), do: @weeks_per_year * config.years_per_game

  @doc "Whether the player reached the end of the last year without the game being over."
  def won?(%__MODULE__{} = game),
    do: game.week >= last_week(game) and not game.game_over

  @doc """
  Starts a run with `config`, which is kept in the game and fixed for the whole run. Without a
  seed one is generated; it is kept in `seed` for replay.
  """
  def new(%Config{} = config, seed \\ nil) do
    {seed, rand} = Random.new(seed)
    {demand_weeks, rand} = Demands.schedule(@weeks_per_year, config, rand)
    buildings = Building.starting()
    stocks = starting_stocks(config)

    %__MODULE__{
      config: config,
      seed: seed,
      rand: rand,
      week: 0,
      demand_weeks: demand_weeks,
      workers: Worker.starting(buildings, config),
      buildings: buildings,
      manameter: config.starting_manameter,
      stocks: stocks,
      report: %WeeklyReport{
        week: 0,
        production: Map.new(Building.products(), &{&1, 0}),
        mana: Map.new(Manameter.colours(), &{&1, 0}),
        manameter: config.starting_manameter,
        food_left: stocks.food,
        newborn: nil,
        trained: [],
        builders: 0,
        travelling: 0,
        gold: stocks.gold,
        tax_due: nil,
        tax: nil,
        demand: nil,
        demand_outcome: nil,
        spoiled: Map.new(Building.products(), &{&1, 0}),
        gold_spent_buildings: 0,
        game_over: false
      }
    }
  end

  @doc "The report of the last week run; for week 0, the starting state."
  def report(%__MODULE__{report: report}), do: report

  @doc """
  Runs the next week. Returns `{:ok, report, game}`; a short week has `food_left < 0`.
  Blocked with `{:error, :game_over}` once the game is over, with `{:error, :finished}` after
  the last week, with `{:error, :tax_undecided}` before a due week until `decide_tax/2` was
  called, and with `{:error, :demand_undecided}` before a demand's deadline week until
  `decide_demand/2` was called.
  """
  def run_week(%__MODULE__{} = game) do
    cond do
      game.game_over -> {:error, :game_over}
      game.week >= last_week(game) -> {:error, :finished}
      tax_decision_due?(game) and is_nil(game.pay_tax) -> {:error, :tax_undecided}
      demand_decision_due?(game) and is_nil(game.deliver_demand) -> {:error, :demand_undecided}
      true -> do_run_week(game)
    end
  end

  defp do_run_week(game) do
    %{workers: workers, buildings: buildings, config: config} = game
    population = length(workers)
    week = game.week + 1
    counted = if Taxes.count_week?(week, config), do: Taxes.assess(workers, config)
    game = if counted, do: %{game | tax_due: counted}, else: game

    production = Production.week(workers, buildings, week, config)
    mana = Mana.week(workers, buildings, week, config)
    start_workers = workers
    workers = Travel.week(workers)
    manameter = ManameterUpdate.update(game.manameter, mana, config)
    stocks = Map.merge(game.stocks, production, fn _product, stock, made -> stock + made end)
    food_left = Food.eat(stocks.food, workers, config)
    {newborn, rand} = Births.attempt(week, food_left, manameter, config, game.rand)
    newborn = newborn && %{newborn | id: Worker.next_id(workers), born_week: week}
    workers = if(newborn, do: workers ++ [newborn], else: workers)

    {buildings, workers, _finished} =
      Construction.week(buildings, start_workers, workers, week, config)

    {workers, trained} = Training.finish(workers, buildings, week, config)

    game = %{
      game
      | rand: rand,
        week: week,
        workers: workers,
        buildings: buildings,
        manameter: manameter,
        stocks: %{stocks | food: food_left}
    }

    {tax, game} = settle_taxes(game)
    {demand_outcome, game} = settle_demand(game)
    {demand, game} = make_demand(game, population)
    {stocks, spoiled} = Spoilage.spoil(game.stocks, config)
    game = %{game | stocks: stocks}

    report = %WeeklyReport{
      WeeklyReport.new(week, game)
      | start: nil,
        production: production,
        mana: mana,
        manameter: manameter,
        food_left: stocks.food,
        newborn: newborn,
        trained: trained,
        builders: Construction.arrived_builders(workers, buildings),
        travelling: Enum.count(workers, &Travel.travelling?/1),
        gold: game.stocks.gold,
        tax_due: counted,
        tax: tax,
        demand: demand,
        demand_outcome: demand_outcome,
        spoiled: spoiled,
        game_over: game.game_over
    }

    {:ok, report, %{game | report: report}}
  end

  @doc "Whether the next week is a due week, so the player must decide on the payment first."
  def tax_decision_due?(%__MODULE__{} = game),
    do: is_integer(game.tax_due) and Taxes.due_week?(game.week + 1, game.config)

  @doc """
  The player's decision for the payment due next week: `true` pays, `false` skips it on
  purpose. Only possible when `tax_decision_due?/1`.
  """
  def decide_tax(%__MODULE__{} = game, pay?) when is_boolean(pay?) do
    if tax_decision_due?(game),
      do: {:ok, %{game | pay_tax: pay?}},
      else: {:error, :no_tax_due}
  end

  @doc "Whether the next week is a demand's deadline, so the player must decide first."
  def demand_decision_due?(%__MODULE__{demand: demand} = game),
    do: demand != nil and demand.due_week == game.week + 1

  @doc """
  The player's decision for the demand due next week: `true` delivers, `false` refuses.
  Only possible when `demand_decision_due?/1`.
  """
  def decide_demand(%__MODULE__{} = game, deliver?) when is_boolean(deliver?) do
    if demand_decision_due?(game),
      do: {:ok, %{game | deliver_demand: deliver?}},
      else: {:error, :no_demand_due}
  end

  @doc """
  Places or moves a worker. It takes its place at once but travels `travel_weeks` first
  (see `Travel`), also when it was still travelling. An unplaced worker can only be placed
  once it has arrived. A finished building must have room; a site takes up to
  `builders_per_building` builders. In the guildhouse the worker starts training after its
  travel (see `Training.check/3`). Moving a trainee out loses its progress; moving a builder
  off a site resets the site's progress to 0.
  """
  def place_worker(%__MODULE__{} = game, worker_id, building_id) do
    with {:ok, worker} <- fetch_worker(game, worker_id),
         {:ok, building} <- fetch_building(game, building_id) do
      cond do
        worker.building == building_id -> {:ok, game}
        error = placement_error(game, worker, building) -> {:error, error}
        trains?(building) -> start_training(game, worker, building_id)
        true -> {:ok, move(game, worker, building_id, nil)}
      end
    end
  end

  defp placement_error(game, worker, building) do
    others = Enum.reject(game.workers, &(&1.id == worker.id))

    cond do
      is_nil(worker.building) and Travel.travelling?(worker) -> :travelling
      not Building.site?(building) and not Building.ready?(building, game.week + 1) -> :not_ready
      not Building.has_room?(building, others, game.config) -> :full
      true -> nil
    end
  end

  defp trains?(building), do: building.type == :guildhouse and not Building.site?(building)

  defp start_training(game, worker, building_id) do
    with :ok <- Training.check(worker, game.manameter, game.config) do
      started = Training.first_week(game.week, game.config)
      {:ok, move(game, worker, building_id, started)}
    end
  end

  @doc """
  Takes a worker out of its building; it travels `travel_weeks` before it can be placed again.
  A trainee loses its progress; a builder resets its site's progress to 0. A worker that is
  already unplaced stays as it is.
  """
  def unplace_worker(%__MODULE__{} = game, worker_id) do
    with {:ok, worker} <- fetch_worker(game, worker_id) do
      if is_nil(worker.building),
        do: {:ok, game},
        else: {:ok, move(game, worker, nil, nil)}
    end
  end

  defp move(game, worker, building_id, training_started) do
    worker = %{worker | training_started: training_started}
    moved = Travel.depart(worker, building_id, game.config)
    game |> reset_site(worker.building) |> put_worker(moved)
  end

  defp reset_site(game, building_id) do
    buildings =
      Enum.map(game.buildings, fn building ->
        if building.id == building_id and Building.site?(building),
          do: %{building | progress: 0},
          else: building
      end)

    %{game | buildings: buildings}
  end

  @doc """
  Orders a new building, which starts as a site (see `Construction`). Every type costs `build_cost_gold`, paid
  from the gold stock now; refused with `{:error, :not_enough_gold}` if the stock is smaller.
  The gold spent is added to `gold_spent_buildings` of the current week's report.
  No limit on number or frequency.
  """
  def construct(%__MODULE__{} = game, type) do
    cost = build_cost(game)

    cond do
      type not in Building.types() ->
        {:error, :unknown_type}

      not can_afford_building?(game) ->
        {:error, :not_enough_gold}

      true ->
        report = %{game.report | gold_spent_buildings: game.report.gold_spent_buildings + cost}

        {:ok,
         %{
           game
           | buildings: Building.construct(game.buildings, type),
             stocks: %{game.stocks | gold: game.stocks.gold - cost},
             report: report
         }}
    end
  end

  @doc "The price of any building, in thousandths of gold."
  def build_cost(%__MODULE__{config: config}), do: Fixed.from(config.build_cost_gold)

  @doc "Whether the gold stock covers the price of a building."
  def can_afford_building?(%__MODULE__{} = game),
    do: game.stocks.gold >= build_cost(game)

  defp settle_taxes(%{tax_due: due} = game) when is_integer(due) do
    if Taxes.due_week?(game.week, game.config) do
      {outcome, gold} = Taxes.settle(game.stocks.gold, due, game.pay_tax)
      game = %{game | stocks: %{game.stocks | gold: gold}, tax_due: nil, pay_tax: nil}
      {outcome, count_miss(game, outcome != :paid)}
    else
      {nil, game}
    end
  end

  defp settle_taxes(game), do: {nil, game}

  defp settle_demand(%{demand: %{due_week: week} = demand, week: week} = game) do
    {outcome, stocks} = Demands.settle(demand, game.stocks, game.deliver_demand)
    game = %{game | stocks: stocks, demand: nil, deliver_demand: nil}
    {outcome, count_miss(game, outcome != :delivered)}
  end

  defp settle_demand(game), do: {nil, game}

  defp make_demand(game, population) do
    if game.week in game.demand_weeks do
      demand =
        Demands.make(game.week, @weeks_per_year, game.manameter, population, game.config)

      {demand, %{game | demand: demand}}
    else
      {nil, game}
    end
  end

  # missed taxes, refused and missed demands share one count
  defp count_miss(game, false), do: game

  defp count_miss(game, true) do
    misses = game.misses + 1
    game_over = game.game_over or Taxes.game_over?(misses, game.config)
    %{game | misses: misses, game_over: game_over}
  end

  defp fetch_worker(game, worker_id) do
    case Enum.find(game.workers, &(&1.id == worker_id)) do
      nil -> {:error, :unknown_worker}
      worker -> {:ok, worker}
    end
  end

  defp fetch_building(game, building_id) do
    case Enum.find(game.buildings, &(&1.id == building_id)) do
      nil -> {:error, :unknown_building}
      building -> {:ok, building}
    end
  end

  defp put_worker(game, worker) do
    %{game | workers: Enum.map(game.workers, &if(&1.id == worker.id, do: worker, else: &1))}
  end

  # products without a starting key begin at 0
  defp starting_stocks(config) do
    Building.products()
    |> Map.new(&{&1, 0})
    |> Map.merge(%{
      food: Food.starting(config),
      gold: Fixed.from(config.starting_gold)
    })
  end
end
