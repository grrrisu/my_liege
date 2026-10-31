defmodule MyLiege.Engine.Game do
  @moduledoc """
  The state of one run and the weekly step. `week` is the last week run: 0 is the starting
  state from the config, and the first week that changes anything is week 1.

  Each week runs in this order: production (and its mana), Manameter update, eating, birth,
  taxes. The village is counted for taxes at the start of a count week, before its birth.
  Stocks are in thousandths (see `Fixed`).
  """

  alias MyLiege.Engine.{
    Births,
    Building,
    Config,
    Fixed,
    Food,
    Mana,
    Manameter,
    ManameterUpdate,
    Production,
    Random,
    Taxes,
    Worker
  }

  @enforce_keys [:seed, :rand, :week, :workers, :buildings, :manameter, :stocks, :report]
  defstruct @enforce_keys ++ [tax_due: nil, pay_tax: nil, tax_misses: 0, game_over: false]

  @doc "Starts a run. Without a seed one is generated; it is kept in `seed` for replay."
  def new(%Config{} = config, seed \\ nil) do
    {seed, rand} = Random.new(seed)
    buildings = Building.starting()
    stocks = starting_stocks(config)

    %__MODULE__{
      seed: seed,
      rand: rand,
      week: 0,
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
        gold: stocks.gold,
        tax_due: nil,
        tax: nil,
        game_over: false
      }
    }
  end

  @doc "The report of the last week run; for week 0, the starting state."
  def report(%__MODULE__{report: report}), do: report

  @doc """
  Runs the next week. Returns `{:ok, report, game}`; a short week has `food_left < 0`.
  Blocked with `{:error, :game_over}` once the game is over, and with
  `{:error, :tax_undecided}` before a due week until `decide_tax/3` was called.
  """
  def run_week(%__MODULE__{} = game, %Config{} = config) do
    cond do
      game.game_over -> {:error, :game_over}
      tax_decision_due?(game, config) and is_nil(game.pay_tax) -> {:error, :tax_undecided}
      true -> do_run_week(game, config)
    end
  end

  defp do_run_week(game, config) do
    %{workers: workers, buildings: buildings} = game
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

    game = %{
      game
      | rand: rand,
        week: week,
        workers: if(newborn, do: workers ++ [newborn], else: workers),
        manameter: manameter,
        stocks: %{stocks | food: food_left}
    }

    {tax, game} = settle_taxes(game, config)

    report = %{
      week: week,
      production: production,
      mana: mana,
      manameter: manameter,
      food_left: food_left,
      newborn: newborn,
      gold: game.stocks.gold,
      tax_due: counted,
      tax: tax,
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

  @doc """
  Places or moves a worker, free and immediate: it works there from the next week run.
  The building must be ready in that week and have room.
  """
  def place_worker(%__MODULE__{} = game, worker_id, building_id, %Config{} = config) do
    with {:ok, worker} <- fetch_worker(game, worker_id),
         {:ok, building} <- fetch_building(game, building_id) do
      others = Enum.reject(game.workers, &(&1.id == worker_id))

      cond do
        worker.building == building_id -> {:ok, game}
        not Building.ready?(building, game.week + 1) -> {:error, :not_ready}
        not Building.has_room?(building, others, config) -> {:error, :full}
        true -> {:ok, put_worker(game, %{worker | building: building_id})}
      end
    end
  end

  @doc "Takes a worker out of its building."
  def unplace_worker(%__MODULE__{} = game, worker_id) do
    with {:ok, worker} <- fetch_worker(game, worker_id) do
      {:ok, put_worker(game, %{worker | building: nil})}
    end
  end

  @doc "Orders a new building; see `Building.construct/4`. No limit on number or frequency."
  def construct(%__MODULE__{} = game, type, %Config{} = config) do
    if type in Building.types() do
      {:ok, %{game | buildings: Building.construct(game.buildings, type, game.week, config)}}
    else
      {:error, :unknown_type}
    end
  end

  defp settle_taxes(%{tax_due: due} = game, config) when is_integer(due) do
    if Taxes.due_week?(game.week, config) do
      {outcome, gold} = Taxes.settle(game.stocks.gold, due, game.pay_tax)
      misses = if outcome == :paid, do: game.tax_misses, else: game.tax_misses + 1

      {outcome,
       %{
         game
         | stocks: %{game.stocks | gold: gold},
           tax_due: nil,
           pay_tax: nil,
           tax_misses: misses,
           game_over: game.game_over or Taxes.game_over?(misses, config)
       }}
    else
      {nil, game}
    end
  end

  defp settle_taxes(game, _config), do: {nil, game}

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
