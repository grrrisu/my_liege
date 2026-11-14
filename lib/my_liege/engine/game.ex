defmodule MyLiege.Engine.Game do
  @moduledoc """
  The state of one run and the weekly step. `week` is the last week run: 0 is the starting
  state from the config, and the first week that changes anything is week 1.

  A week is a pipeline of `MyLiege.Engine.SimStep`s, run in the order of `pipeline/0`, which
  mirrors "Weekly order" in `rules/rules.md`. Each step writes to the game and to the week's
  `MyLiege.Engine.WeeklyReport`.
  Stocks are in thousandths (see `Fixed`).
  """

  alias MyLiege.Engine.Actions.{
    Construct,
    DecideDemand,
    DecideTax,
    PlaceWorker,
    RefuseProject,
    StartBook,
    StartHunt,
    StartInvention,
    UnplaceWorker
  }

  alias MyLiege.Engine.{Config, Fixed, Random, SimSteps, WeeklyReport, Worker}
  alias MyLiege.Engine.Place.{Blueprint, Building}
  alias MyLiege.Engine.Rules.{Bandits, Books, Demands, Food, Suspicion, Taxes}

  @derive {Inspect, except: [:config]}
  @enforce_keys [
    :config,
    :seed,
    :rand,
    :week,
    :workers,
    :places,
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
                bandits: Bandits.starting(),
                books: Books.none(),
                inventions: [],
                suspicion: Suspicion.none(),
                game_over: false
              ]

  @type t :: %__MODULE__{}

  @pipeline [
    SimSteps.TaxCount,
    SimSteps.Production,
    SimSteps.Mana,
    SimSteps.Travel,
    SimSteps.ManameterUpdate,
    SimSteps.Eating,
    SimSteps.Birth,
    SimSteps.Construction,
    SimSteps.Books,
    SimSteps.Inventions,
    SimSteps.Hunts,
    SimSteps.TrainingEnd,
    SimSteps.TaxPayment,
    SimSteps.DemandDelivery,
    SimSteps.DemandMade,
    SimSteps.TradeRoute,
    SimSteps.Bandits,
    SimSteps.Spoilage,
    SimSteps.EndOfWeek
  ]

  # fixed by the designer, not read from the CSV
  @weeks_per_year 48

  def weeks_per_year, do: @weeks_per_year

  @doc "The last week of the game: the end of year `game_years` of the game's config."
  def last_week(%__MODULE__{config: config}), do: @weeks_per_year * config.game_years

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
    places = Building.starting()

    game = %__MODULE__{
      config: config,
      seed: seed,
      rand: rand,
      week: 0,
      demand_weeks: demand_weeks,
      workers: Worker.starting(places, config),
      places: places,
      manameter: config.manameter_start,
      stocks: starting_stocks(config),
      report: nil
    }

    {game, report} = SimSteps.EndOfWeek.run(game, WeeklyReport.new(0, game))
    %{game | report: report}
  end

  @doc """
  The steps of a week, in the order they run. Mirrors "Weekly order" in `rules/rules.md`.
  """
  def pipeline, do: @pipeline

  @doc "The report of the last week run; for week 0, the starting state."
  def report(%__MODULE__{report: report}), do: report

  @doc """
  Runs the next week. Returns `{:ok, report, game}`; a short week has `food_short` (R8).
  Blocked with `{:error, :game_over}` once the game is over, with `{:error, :finished}` after
  the last week, with `{:error, :tax_undecided}` before a due week until `decide_tax/2` was
  called, and with `{:error, :demand_undecided}` before the deadline week of a demand from the
  stock until `decide_demand/2` was called.
  """
  def run_week(%__MODULE__{} = game) do
    with :ok <- runnable(game) do
      report = WeeklyReport.new(game.week + 1, game)
      game = %{game | week: game.week + 1}

      {game, report} =
        Enum.reduce(@pipeline, {game, report}, fn step, {g, r} -> step.run(g, r) end)

      {:ok, report, %{game | report: report}}
    end
  end

  defp runnable(game) do
    cond do
      game.game_over -> {:error, :game_over}
      game.week >= last_week(game) -> {:error, :finished}
      tax_decision_due?(game) and is_nil(game.pay_tax) -> {:error, :tax_undecided}
      demand_decision_due?(game) and is_nil(game.deliver_demand) -> {:error, :demand_undecided}
      true -> :ok
    end
  end

  @doc "Whether the next week is a due week, so the player must decide on the payment first."
  def tax_decision_due?(%__MODULE__{} = game),
    do: is_integer(game.tax_due) and Taxes.due_week?(game.week + 1, game.config)

  @doc "See `MyLiege.Engine.Actions.DecideTax`."
  def decide_tax(%__MODULE__{} = game, pay?), do: DecideTax.run(game, pay?)

  @doc """
  Whether the next week is the deadline of a demand delivered from the stock, so the player
  must decide first. A project (`Demands.project?/1`) needs no decision.
  """
  def demand_decision_due?(%__MODULE__{demand: demand} = game),
    do: demand != nil and not Demands.project?(demand) and demand.due_week == game.week + 1

  @doc "Whether the open demand is a project the player can still refuse."
  def project_refusable?(%__MODULE__{demand: demand} = game),
    do: Demands.project?(demand) and is_nil(game.deliver_demand)

  @doc "See `MyLiege.Engine.Actions.RefuseProject`."
  def refuse_project(%__MODULE__{} = game), do: RefuseProject.run(game)

  @doc "See `MyLiege.Engine.Actions.DecideDemand`."
  def decide_demand(%__MODULE__{} = game, deliver?),
    do: DecideDemand.run(game, deliver?)

  @doc "See `MyLiege.Engine.Actions.PlaceWorker`."
  def place_worker(%__MODULE__{} = game, worker_id, place_id),
    do: PlaceWorker.run(game, worker_id, place_id)

  @doc "See `MyLiege.Engine.Actions.UnplaceWorker`."
  def unplace_worker(%__MODULE__{} = game, worker_id), do: UnplaceWorker.run(game, worker_id)

  @doc "See `MyLiege.Engine.Actions.Construct`."
  def construct(%__MODULE__{} = game, type), do: Construct.run(game, type)

  @doc "See `MyLiege.Engine.Actions.StartBook`."
  def start_book(%__MODULE__{} = game, colour), do: StartBook.run(game, colour)

  @doc "See `MyLiege.Engine.Actions.StartInvention`."
  def start_invention(%__MODULE__{} = game, type), do: StartInvention.run(game, type)

  @doc "See `MyLiege.Engine.Actions.StartHunt`."
  def start_hunt(%__MODULE__{} = game, worker_ids), do: StartHunt.run(game, worker_ids)

  @doc "The price of any building, in thousandths of gold."
  def build_cost(%__MODULE__{config: config}), do: Fixed.from(config.build_cost_gold)

  @doc "Whether the gold stock covers the price of a building."
  def can_afford_building?(%__MODULE__{} = game),
    do: game.stocks.gold >= build_cost(game)

  @doc false
  def fetch_worker(%__MODULE__{} = game, worker_id) do
    case Enum.find(game.workers, &(&1.id == worker_id)) do
      nil -> {:error, :unknown_worker}
      worker -> {:ok, worker}
    end
  end

  @doc false
  def fetch_place(%__MODULE__{} = game, place_id) do
    case Enum.find(game.places, &(&1.id == place_id)) do
      nil -> {:error, :unknown_place}
      place -> {:ok, place}
    end
  end

  @doc false
  def put_worker(%__MODULE__{} = game, worker) do
    %{game | workers: Enum.map(game.workers, &if(&1.id == worker.id, do: worker, else: &1))}
  end

  # products without a starting key begin at 0
  defp starting_stocks(config) do
    Blueprint.goods()
    |> Map.new(&{&1, 0})
    |> Map.merge(%{
      food: Food.starting(config),
      gold: Fixed.from(config.start_gold)
    })
  end
end
