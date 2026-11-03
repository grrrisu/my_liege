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
    {:ok, view, _html} = live(conn, ~p"/game")

    view |> element("#build-market") |> render_click()

    assert has_element?(view, "#building-3", "market")
    assert has_element?(view, "#building-3", "ready in week 2")
  end

  test "the build price is shown; the buttons are disabled once gold is short", %{conn: conn} do
    config = Config.from_csv()
    {:ok, view, _html} = live(conn, ~p"/game")
    affordable = div(config.starting_gold, config.build_cost_gold)

    assert has_element?(view, "#build-cost", "#{config.build_cost_gold} gold")

    for _ <- 1..affordable do
      refute has_element?(view, "#build-farm[disabled]")
      view |> element("#build-farm") |> render_click()
    end

    gold = config.starting_gold - affordable * config.build_cost_gold
    assert has_element?(view, "#stock-gold", "#{gold}")
    assert has_element?(view, "#build-farm[disabled]")
    assert has_element?(view, "#build-guildhouse[disabled]")
  end

  test "placing in an unfinished building shows an error", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")

    view |> element("#build-market") |> render_click()
    view |> element("#worker-1") |> render_click()
    view |> element("#place-3") |> render_click()

    assert has_element?(view, "#flash-error")
    assert has_element?(view, "#building-1 #worker-1")
  end

  test "the tax due is shown after the count; the due week waits for the decision", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/game")

    refute has_element?(view, "#tax-due")
    for _ <- 1..20, do: next_week(view)

    assert has_element?(view, "#tax-counted")
    assert has_element?(view, "#tax-due", "due in week 24")
    refute has_element?(view, "#tax-decision")

    for _ <- 21..23, do: next_week(view)

    assert has_element?(view, "#tax-decision")
    assert has_element?(view, "#next-week[disabled]")

    view |> element("#skip-tax") |> render_click()
    deliver_demand(view)
    refute has_element?(view, "#next-week[disabled]")
    view |> element("#next-week") |> render_click()

    assert has_element?(view, "#week", "Week 24")
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
    for _ <- 1..20, do: next_week(view)

    assert has_element?(view, "#flash-info", "gold tax due in week 24")
  end

  test "an info is shown when the king makes a demand", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")

    Enum.find(1..24, fn _ ->
      next_week(view)
      has_element?(view, "#demand-made")
    end)

    assert has_element?(view, "#flash-info", "The king demands")
  end

  test "an info is shown exactly when the tax couldn't be paid", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")
    for _ <- 1..23, do: next_week(view)

    view |> element("#pay-tax") |> render_click()
    next_week(view)

    # the seed is random, so the tax may or may not have been affordable
    assert has_element?(view, "#tax-outcome", "missed") ==
             has_element?(view, "#flash-info", "couldn't be paid")
  end

  test "the download button sends the CSV report of all weeks so far", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")
    for _ <- 1..2, do: next_week(view)

    view |> element("#download-csv") |> render_click()

    assert_push_event(view, "download_csv", %{filename: filename, content: content})
    assert filename =~ ~r/^my_liege_seed_\d+_week_2\.csv$/
    assert content |> String.split("\n", trim: true) |> length() == 4
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
