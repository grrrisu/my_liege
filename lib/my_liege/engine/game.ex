defmodule MyLiege.Engine.Game do
  @moduledoc """
  The state of one run and the weekly step. `week` is the last week run: 0 is the starting
  state from the config, and the first week that changes anything is week 1.

  Each week runs in this order: production (and its mana), Manameter update, eating, birth.
  Taxes are not part of the week yet. Stocks are in thousandths (see `Fixed`).
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
    Worker
  }

  @enforce_keys [:seed, :rand, :week, :workers, :buildings, :manameter, :stocks, :report]
  defstruct @enforce_keys

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
        newborn: nil
      }
    }
  end

  @doc "The report of the last week run; for week 0, the starting state."
  def report(%__MODULE__{report: report}), do: report

  @doc "Runs the next week. Returns `{report, game}`; a short week has `food_left < 0`."
  def run_week(%__MODULE__{} = game, %Config{} = config) do
    %{workers: workers, buildings: buildings} = game
    week = game.week + 1

    production = Production.week(workers, buildings, week, config)
    mana = Mana.week(workers, buildings, week, config)
    manameter = ManameterUpdate.update(game.manameter, mana, config)
    stocks = Map.merge(game.stocks, production, fn _product, stock, made -> stock + made end)
    food_left = Food.eat(stocks.food, workers, config)
    {newborn, rand} = Births.attempt(week, food_left, manameter, config, game.rand)

    report = %{
      week: week,
      production: production,
      mana: mana,
      manameter: manameter,
      food_left: food_left,
      newborn: newborn
    }

    game = %{
      game
      | rand: rand,
        week: week,
        workers: if(newborn, do: workers ++ [newborn], else: workers),
        manameter: manameter,
        stocks: %{stocks | food: food_left},
        report: report
    }

    {report, game}
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
