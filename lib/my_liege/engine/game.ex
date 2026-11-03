defmodule MyLiege.Engine.Game do
  @moduledoc """
  The state of one run and the weekly step. `week` is the last week run: 0 is the starting
  state from the config, and the first week that changes anything is week 1.

  Each week runs in this order: production (and its mana), Manameter update, eating, birth,
  training, taxes, demands, spoilage. The village is counted for taxes at the start of a count week, before its birth.
  Stocks are in thousandths (see `Fixed`).
  """

  alias MyLiege.Engine.{
    Births,
    Building,
    Config,
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
    Worker
  }

  @enforce_keys [
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

  @doc "The last week of the game: the end of year `years_per_game`."
  def last_week(%Config{} = config), do: @weeks_per_year * config.years_per_game

  @doc "Whether the player reached the end of the last year without the game being over."
  def won?(%__MODULE__{} = game, %Config{} = config),
    do: game.week >= last_week(config) and not game.game_over

  @doc "Starts a run. Without a seed one is generated; it is kept in `seed` for replay."
  def new(%Config{} = config, seed \\ nil) do
    {seed, rand} = Random.new(seed)
    {demand_weeks, rand} = Demands.schedule(@weeks_per_year, config, rand)
    buildings = Building.starting()
    stocks = starting_stocks(config)

    %__MODULE__{
      seed: seed,
      rand: rand,
      week: 0,
      demand_weeks: demand_weeks,
      workers: Worker.starting(buildings, config),
      buildings: buildings,
      manameter: config.starting_manameter,
      stocks: stocks,
      report: %{
        week: 0,
        production: Map.new(Building.products(), &{&1, 0}),
        mana: Map.new(Manameter.colours(), &{&1, 0}),
        manameter: config.starting_manameter,
        food_left: stocks.food,
        newborn: nil,
        trained: [],
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
  the last week, with `{:error, :tax_undecided}` before a due week until `decide_tax/3` was
  called, and with `{:error, :demand_undecided}` before a demand's deadline week until
  `decide_demand/2` was called.
  """
  def run_week(%__MODULE__{} = game, %Config{} = config) do
    cond do
      game.game_over -> {:error, :game_over}
      game.week >= last_week(config) -> {:error, :finished}
      tax_decision_due?(game, config) and is_nil(game.pay_tax) -> {:error, :tax_undecided}
      demand_decision_due?(game) and is_nil(game.deliver_demand) -> {:error, :demand_undecided}
      true -> do_run_week(game, config)
    end
  end

  defp do_run_week(game, config) do
    %{workers: workers, buildings: buildings} = game
    population = length(workers)
    week = game.week + 1
    counted = if Taxes.count_week?(week, config), do: Taxes.assess(workers, config)
    game = if counted, do: %{game | tax_due: counted}, else: game

    production = Production.week(workers, buildings, week, config)
    mana = Mana.week(workers, buildings, week, config)
    manameter = ManameterUpdate.update(game.manameter, mana, config)
    stocks = Map.merge(game.stocks, production, fn _product, stock, made -> stock + made end)
    food_left = Food.eat(stocks.food, workers, config)
    {newborn, rand} = Births.attempt(week, food_left, manameter, config, game.rand)
    newborn = newborn && %{newborn | id: Worker.next_id(workers), born_week: week}
    workers = if(newborn, do: workers ++ [newborn], else: workers)
    {workers, trained} = Training.finish(workers, buildings, week, config)

    game = %{
      game
      | rand: rand,
        week: week,
        workers: workers,
        manameter: manameter,
        stocks: %{stocks | food: food_left}
    }

    {tax, game} = settle_taxes(game, config)
    {demand_outcome, game} = settle_demand(game, config)
    {demand, game} = make_demand(game, population, config)
    {stocks, spoiled} = Spoilage.spoil(game.stocks, config)
    game = %{game | stocks: stocks}

    report = %{
      week: week,
      production: production,
      mana: mana,
      manameter: manameter,
      food_left: stocks.food,
      newborn: newborn,
      trained: trained,
      gold: game.stocks.gold,
      tax_due: counted,
      tax: tax,
      demand: demand,
      demand_outcome: demand_outcome,
      spoiled: spoiled,
      gold_spent_buildings: 0,
      game_over: game.game_over
    }

    {:ok, report, %{game | report: report}}
  end

  @doc "Whether the next week is a due week, so the player must decide on the payment first."
  def tax_decision_due?(%__MODULE__{} = game, %Config{} = config),
    do: is_integer(game.tax_due) and Taxes.due_week?(game.week + 1, config)

  @doc """
  The player's decision for the payment due next week: `true` pays, `false` skips it on
  purpose. Only possible when `tax_decision_due?/2`.
  """
  def decide_tax(%__MODULE__{} = game, pay?, %Config{} = config) when is_boolean(pay?) do
    if tax_decision_due?(game, config),
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
  Places or moves a worker, free and immediate: it works there from the next week run.
  The building must be ready in that week and have room. In the guildhouse the worker starts
  training (see `Training.check/3`); moving a trainee out loses its progress.
  """
  def place_worker(%__MODULE__{} = game, worker_id, building_id, %Config{} = config) do
    with {:ok, worker} <- fetch_worker(game, worker_id),
         {:ok, building} <- fetch_building(game, building_id) do
      others = Enum.reject(game.workers, &(&1.id == worker_id))

      cond do
        worker.building == building_id -> {:ok, game}
        not Building.ready?(building, game.week + 1) -> {:error, :not_ready}
        not Building.has_room?(building, others, config) -> {:error, :full}
        building.type == :guildhouse -> start_training(game, worker, building_id, config)
        true -> {:ok, put_worker(game, %{worker | building: building_id, training_started: nil})}
      end
    end
  end

  defp start_training(game, worker, building_id, config) do
    with :ok <- Training.check(worker, game.manameter, config) do
      trainee = %{worker | building: building_id, training_started: game.week + 1}
      {:ok, put_worker(game, trainee)}
    end
  end

  @doc "Takes a worker out of its building; a trainee loses its progress."
  def unplace_worker(%__MODULE__{} = game, worker_id) do
    with {:ok, worker} <- fetch_worker(game, worker_id) do
      {:ok, put_worker(game, %{worker | building: nil, training_started: nil})}
    end
  end

  @doc """
  Orders a new building; see `Building.construct/4`. Every type costs `build_cost_gold`, paid
  from the gold stock now; refused with `{:error, :not_enough_gold}` if the stock is smaller.
  The gold spent is added to `gold_spent_buildings` of the current week's report.
  No limit on number or frequency.
  """
  def construct(%__MODULE__{} = game, type, %Config{} = config) do
    cost = build_cost(config)

    cond do
      type not in Building.types() ->
        {:error, :unknown_type}

      not can_afford_building?(game, config) ->
        {:error, :not_enough_gold}

      true ->
        report = Map.update!(game.report, :gold_spent_buildings, &(&1 + cost))

        {:ok,
         %{
           game
           | buildings: Building.construct(game.buildings, type, game.week, config),
             stocks: %{game.stocks | gold: game.stocks.gold - cost},
             report: report
         }}
    end
  end

  @doc "The price of any building, in thousandths of gold."
  def build_cost(%Config{} = config), do: Fixed.from(config.build_cost_gold)

  @doc "Whether the gold stock covers the price of a building."
  def can_afford_building?(%__MODULE__{} = game, %Config{} = config),
    do: game.stocks.gold >= build_cost(config)

  defp settle_taxes(%{tax_due: due} = game, config) when is_integer(due) do
    if Taxes.due_week?(game.week, config) do
      {outcome, gold} = Taxes.settle(game.stocks.gold, due, game.pay_tax)
      game = %{game | stocks: %{game.stocks | gold: gold}, tax_due: nil, pay_tax: nil}
      {outcome, count_miss(game, outcome != :paid, config)}
    else
      {nil, game}
    end
  end

  defp settle_taxes(game, _config), do: {nil, game}

  defp settle_demand(%{demand: %{due_week: week} = demand, week: week} = game, config) do
    {outcome, stocks} = Demands.settle(demand, game.stocks, game.deliver_demand)
    game = %{game | stocks: stocks, demand: nil, deliver_demand: nil}
    {outcome, count_miss(game, outcome != :delivered, config)}
  end

  defp settle_demand(game, _config), do: {nil, game}

  defp make_demand(game, population, config) do
    if game.week in game.demand_weeks do
      demand = Demands.make(game.week, @weeks_per_year, game.manameter, population, config)
      {demand, %{game | demand: demand}}
    else
      {nil, game}
    end
  end

  # missed taxes, refused and missed demands share one count
  defp count_miss(game, false, _config), do: game

  defp count_miss(game, true, config) do
    misses = game.misses + 1
    %{game | misses: misses, game_over: game.game_over or Taxes.game_over?(misses, config)}
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
