defmodule MyLiegeWeb.GameLiveTest do
  use MyLiegeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

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

  test "placing in an unfinished building shows an error", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/game")

    view |> element("#build-market") |> render_click()
    view |> element("#worker-1") |> render_click()
    view |> element("#place-3") |> render_click()

    assert has_element?(view, "#flash-error")
    assert has_element?(view, "#building-1 #worker-1")
  end
end
