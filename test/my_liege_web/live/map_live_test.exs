defmodule MyLiegeWeb.MapLiveTest do
  use MyLiegeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the five layout regions", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/map")

    assert has_element?(view, "#game.game-shell")

    for id <- ~w(timer left map right footer) do
      assert has_element?(view, "##{id}")
    end
  end

  test "the timer shows the seasons strip and the sun", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/map")

    assert has_element?(view, ~s|#timer svg image[href="/images/seasons.png"]|)
    assert has_element?(view, ~s|#timer svg image[href="/images/sun.png"]|)
  end

  test "the map shows the landscape", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/map")

    assert has_element?(view, ~s|#map svg image[href="/images/landscape.png"]|)
  end
end
