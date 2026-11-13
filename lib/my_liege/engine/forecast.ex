defmodule MyLiege.Engine.Forecast do
  @moduledoc """
  T77, forecasts "if nothing changes": each one repeats the change of the last week run (its end
  minus its start, from `WeeklyReport.stock_change` and `project_change`) unchanged for every
  week ahead. Changes are raw: a week with a tax payment, a delivered demand, the king's takings
  or a raid counts them in; gold spent on buildings between weeks does not.

  There are no forecasts in week 0, which has no week before it; only the amount and week of the
  next tax are known then. A forecast only reads the game: it never changes it. The AutoRun bots
  use the same functions.

  Amounts are in thousandths (see `Fixed`).
  """

  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Rules.{Bandits, Demands, Taxes}

  @type direction :: :rising | :falling | :steady

  @doc "Whether a change makes a stock (or the threat) rise, fall or stay."
  def direction(change) when change > 0, do: :rising
  def direction(change) when change < 0, do: :falling
  def direction(_change), do: :steady

  @doc """
  The food stock's change in the last week and, if it falls, `weeks_left`: the weeks until it
  goes below 0 (0 if it already is), otherwise `nil`. `nil` in week 0.
  """
  def food(%Game{} = game) do
    with change when is_integer(change) <- change(game, :food) do
      stock = game.stocks.food

      weeks_left =
        cond do
          change >= 0 -> nil
          stock < 0 -> 0
          true -> div(stock, -change) + 1
        end

      %{change: change, direction: direction(change), weeks_left: weeks_left}
    end
  end

  @doc "The gold stock's change in the last week, spoilage included. `nil` in week 0."
  def gold(%Game{} = game) do
    with change when is_integer(change) <- change(game, :gold) do
      %{change: change, direction: direction(change)}
    end
  end

  @doc """
  The next tax amount: as fixed at the count, or before the count `king_tax_per_worker` for every
  current worker (births before the count can still raise it).
  """
  def tax_amount(%Game{} = game), do: game.tax_due || Taxes.assess(game.workers, game.config)

  @doc """
  The next tax payment within the game: `amount` (`tax_amount/1`), `due_week`, `counted?`,
  `expected_gold` (the gold now plus the last week's change for every week until and including
  the due week; `nil` in week 0) and `shortfall` (what the expected gold lacks, 0 if none; `nil`
  in week 0). `nil` if no payment is left in the game.
  """
  def next_tax(%Game{} = game) do
    due_week = Taxes.next_due_week(game.week, game.config)

    if due_week <= Game.last_week(game) do
      amount = tax_amount(game)
      expected = project(game.stocks.gold, change(game, :gold), due_week - game.week)

      %{
        amount: amount,
        due_week: due_week,
        counted?: is_integer(game.tax_due),
        expected_gold: expected,
        shortfall: expected && max(amount - expected, 0)
      }
    end
  end

  @doc """
  The open demand: `product`, `amount`, `due_week`, `expected` (what there will be by the
  deadline, the deadline week included: for a project its progress plus the last week's gain for
  every week left, at most the amount; otherwise the stock plus its last week's change for every
  week left) and `met?`. `expected` and `met?` are `nil` while the last week gives no change (week
  0, or a project made in the last week). `nil` with no open demand or a refused project.
  """
  def demand(%Game{demand: nil}), do: nil

  def demand(%Game{demand: demand} = game) do
    if Demands.project?(demand) and game.deliver_demand == false do
      nil
    else
      expected = expected(game, demand, demand.due_week - game.week)

      %{
        product: demand.product,
        amount: demand.amount,
        due_week: demand.due_week,
        expected: expected,
        met?: expected && expected >= demand.amount
      }
    end
  end

  defp expected(game, demand, weeks) do
    if Demands.project?(demand) do
      %{progress: progress} = Demands.project(demand, game.places)
      expected = project(progress, game.report.project_change, weeks)
      expected && min(expected, demand.amount)
    else
      game.stocks
      |> Map.fetch!(demand.product)
      |> project(change(game, demand.product), weeks)
    end
  end

  @doc """
  The bandit threat: `change` and `direction` in the last week, and `weeks_to_threshold` at the
  last week's pressure: the weeks until the threat reaches `bandit_threshold` when it rises by
  pressure − 1000 every week, 1 if the pressure was unbounded, `:never` at a pressure of 1000 or
  less. The rising floor is left out. `nil` in week 0 and while bandits are on their way.
  """
  def bandits(%Game{week: 0}), do: nil

  def bandits(%Game{} = game) do
    if Bandits.on_their_way?(game.bandits) do
      nil
    else
      change = game.report.bandit_threat_change

      %{
        change: change,
        direction: direction(change),
        weeks_to_threshold: weeks_to_threshold(game, game.report.bandit_pressure)
      }
    end
  end

  defp weeks_to_threshold(_game, :unbounded), do: 1
  defp weeks_to_threshold(_game, pressure) when pressure <= 1000, do: :never

  defp weeks_to_threshold(game, pressure) do
    missing = max(Bandits.threshold(game.config) - game.bandits.threat, 1)
    rise = pressure - 1000
    div(missing + rise - 1, rise)
  end

  defp change(%Game{report: %{stock_change: nil}}, _product), do: nil
  defp change(%Game{report: report}, product), do: Map.fetch!(report.stock_change, product)

  defp project(_now, nil, _weeks), do: nil
  defp project(now, change, weeks), do: now + change * weeks
end
