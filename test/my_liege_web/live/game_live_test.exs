defmodule MyLiegeWeb.GameLiveTest do
  use MyLiegeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias MyLiege.Engine.Config

  test "shows the starting state as week 0", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")

    assert has_element?(view, "#week", "Week 0")
    assert has_element?(view, "#manameter")
    assert has_element?(view, "#stocks")
    assert has_element?(view, "#building-1")
    assert has_element?(view, "#building-2")
  end

  test "the next-week button runs week 1", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")

    view |> element("#next-week") |> render_click()

    assert has_element?(view, "#week", "Week 1")
    assert has_element?(view, "#last-week", "Week 1")
  end

  test "forecasts appear from week 1, the next tax already in week 0", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")

    assert has_element?(view, "#forecast-tax")
    refute has_element?(view, "#forecast-tax-outcome")
    refute has_element?(view, "#forecast-food")
    refute has_element?(view, "#forecast-bandits")

    view |> element("#next-week") |> render_click()

    assert has_element?(view, "#forecast-food")
    assert has_element?(view, "#forecast-gold")
    assert has_element?(view, "#forecast-tax-outcome")
    assert has_element?(view, "#forecast-bandits")
  end

  test "select a worker and place it in another building", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")

    view |> element("#worker-1") |> render_click()
    view |> element("#place-2") |> render_click()

    assert has_element?(view, "#building-2 #worker-1")
    refute has_element?(view, "#building-1 #worker-1")
  end

  test "take a worker out of its building", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")

    view |> element("#worker-1") |> render_click()
    view |> element("#unplace") |> render_click()

    assert has_element?(view, "#unplaced #worker-1")
  end

  test "order a new building", %{conn: conn} do
    config = Config.from_csv()
    {:ok, view, _html} = live(conn, ~p"/game")

    view |> element("#build-market") |> render_click()

    assert has_element?(view, "#building-3", "market site")
    assert has_element?(view, "#site-3", "builders arrived 0/#{config.build_capacity}")
    assert has_element?(view, "#site-3", "progress 0/#{config.build_work}")
  end

  test "the build price is shown; the buttons are disabled once gold is short", %{conn: conn} do
    config = Config.from_csv()
    {:ok, view, _html} = live(conn, ~p"/game")
    affordable = div(config.start_gold, config.build_cost_gold)

    assert has_element?(view, "#build-cost", "#{config.build_cost_gold} gold")

    for _ <- 1..affordable do
      refute has_element?(view, "#build-farm[disabled]")
      view |> element("#build-farm") |> render_click()
    end

    gold = config.start_gold - affordable * config.build_cost_gold
    assert has_element?(view, "#stock-gold", "#{gold}")
    assert has_element?(view, "#build-farm[disabled]")
    assert has_element?(view, "#build-guildhouse[disabled]")
  end

  test "a worker placed on a site is a builder and travels first", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")

    view |> element("#build-market") |> render_click()
    view |> element("#worker-1") |> render_click()
    view |> element("#place-3") |> render_click()

    config = Config.from_csv()
    needed = config.build_capacity

    assert has_element?(view, "#building-3 #worker-1")
    assert has_element?(view, "#travel-1", "#{config.travel_weeks}")
    assert has_element?(view, "#site-3", "builders arrived 0/#{needed}")

    for _ <- 1..config.travel_weeks, do: view |> element("#next-week") |> render_click()

    refute has_element?(view, "#travel-1")
    assert has_element?(view, "#site-3", "builders arrived 1/#{needed}")
  end

  test "a travelling unplaced worker can't be placed", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")

    view |> element("#worker-1") |> render_click()
    view |> element("#unplace") |> render_click()
    view |> element("#worker-1") |> render_click()
    view |> element("#place-2") |> render_click()

    assert has_element?(view, "#flash-error")
    assert has_element?(view, "#unplaced #worker-1")
  end

  test "the tax due is shown after the count; the due week waits for the decision", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/game")

    refute has_element?(view, "#tax-due")
    # the grace period of the CSV (24 weeks) skips the tax due in week 24
    for _ <- 1..44, do: next_week(view)

    assert has_element?(view, "#tax-counted")
    assert has_element?(view, "#tax-due", "due in week 48")
    refute has_element?(view, "#tax-decision")

    for _ <- 45..47, do: next_week(view)

    assert has_element?(view, "#tax-decision")
    assert has_element?(view, "#next-week[disabled]")

    view |> element("#skip-tax") |> render_click()
    deliver_demand(view)
    refute has_element?(view, "#next-week[disabled]")
    view |> element("#next-week") |> render_click()

    assert has_element?(view, "#week", "Week 48")
    assert has_element?(view, "#tax-outcome", "skipped")
  end

  test "buildings and workers are in the first column, the read-only state in the second", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/game")

    assert has_element?(view, "#column-village #buildings")
    assert has_element?(view, "#column-village #build")

    for id <- ~w(manameter stocks taxes demands last-week) do
      assert has_element?(view, "#column-state ##{id}")
    end
  end

  test "an info is shown when the village is counted for taxes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")
    for _ <- 1..44, do: next_week(view)

    assert has_element?(view, "#flash-info", "gold tax due in week 48")
  end

  test "an info is shown when the king makes a demand", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")

    Enum.find(1..48, fn _ ->
      next_week(view)
      has_element?(view, "#demand-made")
    end)

    assert has_element?(view, "#flash-info", "The king demands")
  end

  test "an info is shown exactly when the tax couldn't be paid", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")
    for _ <- 1..47, do: next_week(view)

    view |> element("#pay-tax") |> render_click()
    next_week(view)

    # the seed is random, so the tax may or may not have been affordable
    assert has_element?(view, "#tax-outcome", "missed") ==
             has_element?(view, "#flash-info", "couldn't be paid")
  end

  test "the grace period is shown while it runs, with its last week", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")

    assert has_element?(view, "#grace-period", "week 24")
    for _ <- 1..23, do: next_week(view)
    assert has_element?(view, "#grace-period")

    next_week(view)
    refute has_element?(view, "#grace-period")
  end

  test "happiness of the last week is shown next to the stocks, from week 1", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")

    assert has_element?(view, "#happiness")
    refute has_element?(view, "#happiness-now")

    # no tavern: in the grace period the step is 0, but it would be −3
    next_week(view)
    assert has_element?(view, "#happiness-now", "step 0")
    assert has_element?(view, "#happiness", "would be -3")
    refute has_element?(view, "#forecast-happiness")
  end

  test "the download button sends the CSV report of all weeks so far", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")
    for _ <- 1..2, do: next_week(view)

    view |> element("#download-csv") |> render_click()

    assert_push_event(view, "download_csv", %{filename: filename, content: content})
    assert filename =~ ~r/^my_liege_seed_\d+_week_2\.csv$/
    assert content |> String.split("\n", trim: true) |> length() == 4
  end

  test "shows the bandit threat, its direction and the protected gold", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")

    assert has_element?(view, "#bandit-threat")
    assert has_element?(view, "#protected-gold")
    refute has_element?(view, "#bandits-approaching")

    # the starting gold is more than the one soldier protects
    next_week(view)
    assert has_element?(view, "#bandit-threat-direction", "rising")
  end

  test "approaching bandits are shown with the weeks left until the raid", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")

    Enum.find(1..Config.from_csv().king_grace_weeks, fn _ ->
      next_week(view)
      has_element?(view, "#bandits-approaching")
    end)

    assert has_element?(
             view,
             "#bandits-approaching",
             "#{Config.from_csv().bandit_warning_weeks} weeks left"
           )

    refute has_element?(view, "#bandit-threat-direction")
  end

  defp next_week(view) do
    deliver_demand(view)
    view |> element("#next-week") |> render_click()
  end

  defp deliver_demand(view) do
    if has_element?(view, "#demand-decision"),
      do: view |> element("#deliver-demand") |> render_click()
  end
end
