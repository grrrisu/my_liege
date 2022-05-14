defmodule MyLiegeWeb.BoardLive.IndexTest do
  use MyLiegeWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import MyLiege.RealmHelper

  alias MyLiege.Game.Board

  setup do
    set_realm(%Board{})
    :ok
  end

  test "redirect to dashboard", %{conn: conn} do
    set_realm(nil)
    {:error, {:redirect, %{to: "/"}}} = live(conn, "/board")
  end

  test "board index", %{conn: conn} do
    conn = get(conn, "/board")
    assert html_response(conn, 200) =~ "<h1>My Liege - Board</h1>"

    {:ok, _view, html} = live(conn)
    assert html =~ "<h1>My Liege - Board</h1>"
  end

  test "start and stop sim", %{conn: conn} do
    {:ok, view, html} = live(conn, "/board")
    assert html =~ "start"
    send(view.pid, {:sim_started, started: true})
    assert render(view) =~ "stop"
    send(view.pid, {:sim_started, started: false})
    assert render(view) =~ "start"
  end

  test "game over", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/board")
    send(view.pid, {:game_over, reason: "all pawns died"})
    assert render(view) =~ "all pawns died"
  end
end
