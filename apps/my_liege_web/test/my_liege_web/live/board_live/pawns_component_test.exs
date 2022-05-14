defmodule MyLiegeWeb.BoardLive.PawnsComponentTest do
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
    assert view |> element("section#pawns") |> has_element?()
  end

  test "pawns changed", %{conn: conn} do
    set_realm(%Board{pawn_pool: %{normal: 10}, poverty: %{normal: 5}})
    {:ok, view, _html} = live(conn, "/board")
    assert view |> element("#pawn-pool") |> render() =~ "10"
    assert view |> element("#poverty") |> render() =~ "5"
    change_realm(%{pawn_pool: %{normal: -2}, poverty: %{normal: 2}})
    send(view.pid, {:pawns_changed, changes: "changes"})
    render(view)
    assert view |> element("#pawn-pool") |> render() =~ "8"
    assert view |> element("#poverty") |> render() =~ "7"
  end

  test "pawn added to pool", %{conn: conn} do
    set_realm(%Board{pawn_pool: %{normal: 10}, poverty: %{normal: 5}})
    {:ok, view, _html} = live(conn, "/board")
    assert view |> element("#pawn-pool") |> render() =~ "10"
    assert view |> element("#poverty") |> render() =~ "5"
    change_realm(%{pawn_pool: %{normal: 2}})
    send(view.pid, {:pawn_added_to_pool, changes: "changes"})
    render(view)
    assert view |> element("#pawn-pool") |> render() =~ "12"
    assert view |> element("#poverty") |> render() =~ "5"
  end

  test "pawn removed from pool", %{conn: conn} do
    set_realm(%Board{pawn_pool: %{normal: 10}, poverty: %{normal: 5}})
    {:ok, view, _html} = live(conn, "/board")
    assert view |> element("#pawn-pool") |> render() =~ "10"
    assert view |> element("#poverty") |> render() =~ "5"
    change_realm(%{pawn_pool: %{normal: -4}})
    send(view.pid, {:pawn_removed_from_pool, changes: "changes"})
    render(view)
    assert view |> element("#pawn-pool") |> render() =~ "6"
    assert view |> element("#poverty") |> render() =~ "5"
  end
end
