defmodule MyLiegeWeb.BoardLive.IndexTest do
  use MyLiegeWeb.ConnCase
  import Phoenix.LiveViewTest

  setup do
    :ok = Phoenix.PubSub.subscribe(MyLiege.PubSub, "Game")
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
end
