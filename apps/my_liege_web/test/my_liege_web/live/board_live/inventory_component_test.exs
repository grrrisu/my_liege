defmodule MyLiegeWeb.BoardLive.InventoryComponentTest do
  use MyLiegeWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import MyLiege.RealmHelper

  alias MyLiege.Game.Board

  setup do
    set_realm(%Board{})
    :ok
  end

  test "empty", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/board")
    assert view |> element("section#inventory") |> has_element?()
  end

  test "update inventory", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/board")
    refute view |> element("#inventory-food") |> has_element?()
    change_realm(%{inventory: %{food: 10}})
    send(view.pid, {:inventory_updated, input: %{food: 10}})
    render(view)
    assert view |> element("#inventory-food") |> render() =~ "10"
  end
end
