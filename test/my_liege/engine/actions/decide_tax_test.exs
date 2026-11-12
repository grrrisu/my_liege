defmodule MyLiege.Engine.Actions.DecideTaxTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Actions.DecideTax
  alias MyLiege.EngineFixtures

  # taxes are due in week 24; the game stands at week 23 with an amount counted
  setup do
    game = EngineFixtures.game_without_demands(EngineFixtures.config(), 1)
    %{game: %{game | week: 23, tax_due: 20_000}}
  end

  test "stores the decision to pay", %{game: game} do
    assert {:ok, %{pay_tax: true}} = DecideTax.run(game, true)
  end

  test "stores the decision to skip", %{game: game} do
    assert {:ok, %{pay_tax: false}} = DecideTax.run(game, false)
  end

  test "refused when the next week is not a due week", %{game: game} do
    assert DecideTax.run(%{game | week: 22}, true) == {:error, :no_tax_due}
  end

  test "refused when no amount was counted", %{game: game} do
    assert DecideTax.run(%{game | tax_due: nil}, true) == {:error, :no_tax_due}
  end
end
