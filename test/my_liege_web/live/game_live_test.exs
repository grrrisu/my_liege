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
end
