defmodule MyLiegeWeb.DashboardLive.IndexTest do
  use MyLiegeWeb.ConnCase
  import Phoenix.LiveViewTest

  setup do
    :ok = Phoenix.PubSub.subscribe(MyLiege.PubSub, "Game")
  end

  test "dashboard index", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "<h1>My Liege</h1>"

    {:ok, _view, html} = live(conn)
    assert html =~ "<h1>My Liege</h1>"
  end

  test "push create level event", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/create?name=test")
    assert html =~ "creating level test ..."
  end

  test "redirect to board after creation", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    send(view.pid, {:game_created, name: "test"})
    assert_redirect(view, "/board")
  end

  test "show error from service execution", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    send(view.pid, {:error, "error message"})
    assert render(view) =~ "error message"
  end
end
