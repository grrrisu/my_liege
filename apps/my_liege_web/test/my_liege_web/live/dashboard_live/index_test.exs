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

  test "redirect to board after creation", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/board", flash: %{"info" => "created level one"}}}} =
             live(conn, "/create?level=one")
  end
end
