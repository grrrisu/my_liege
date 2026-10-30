defmodule MyLiege.Engine.ManameterUpdateTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Manameter, ManameterUpdate}
  alias MyLiege.EngineFixtures

  @no_mana %{green: 0, blue: 0, red: 0, yellow: 0, violet: 0}

  describe "R4: Manameter update" do
    setup do
      config = EngineFixtures.config()
      %{config: config, manameter: config.starting_manameter}
    end

    test "3 points: removed by current shares, added by the week's mana", context do
      %{config: config, manameter: manameter} = context
      mana = %{@no_mana | red: 3}

      # exact: 797.6, 49.85, 102.7, 49.85, 0
      assert ManameterUpdate.update(manameter, mana, config) ==
               shares(797, 50, 103, 50, 0)
    end

    test "a colour with no share gains when it makes mana", context do
      %{config: config, manameter: manameter} = context
      mana = %{@no_mana | violet: 3}

      # exact: 797.6, 49.85, 99.7, 49.85, 3
      assert ManameterUpdate.update(manameter, mana, config) ==
               shares(797, 50, 100, 50, 3)
    end

    test "a gain of less than one share can be lost to rounding", context do
      %{config: config, manameter: manameter} = context
      mana = %{@no_mana | green: 15, red: 5}

      # exact: 799.85, 49.85, 100.45, 49.85, 0
      assert ManameterUpdate.update(manameter, mana, config) == manameter
    end

    test "the Manameter stays unchanged in a week without mana", context do
      %{config: config, manameter: manameter} = context

      assert ManameterUpdate.update(manameter, @no_mana, config) == manameter
    end

    test "the points per week come from the configuration", context do
      %{manameter: manameter} = context
      config = EngineFixtures.config(manameter_points_per_week: 20)
      mana = %{@no_mana | red: 1}

      assert ManameterUpdate.update(manameter, mana, config) ==
               shares(784, 49, 118, 49, 0)
    end

    test "leftover units go to the largest remainders, ties in pentagon order" do
      config = EngineFixtures.config(manameter_points_per_week: 2)
      mana = %{@no_mana | blue: 1, red: 1, yellow: 1}

      # blue, red and yellow each gain 0.67; the two leftover units go to blue and red
      assert ManameterUpdate.update(shares(1000, 0, 0, 0, 0), mana, config) ==
               shares(998, 1, 1, 0, 0)
    end

    test "shares always sum to 100% and never go below 0", context do
      %{config: config, manameter: manameter} = context

      weekly_mana = [
        %{@no_mana | red: 9},
        %{@no_mana | blue: 2, yellow: 7},
        %{@no_mana | violet: 1, green: 30},
        @no_mana,
        %{green: 1, blue: 1, red: 1, yellow: 1, violet: 1}
      ]

      weekly_mana
      |> Stream.cycle()
      |> Enum.take(144)
      |> Enum.reduce(manameter, fn mana, current_manameter ->
        current_manameter = ManameterUpdate.update(current_manameter, mana, config)
        shares = Enum.map(Manameter.colours(), &Map.fetch!(current_manameter, &1))

        assert Enum.sum(shares) == Manameter.total_shares()
        assert Enum.all?(shares, &(&1 >= 0))
        current_manameter
      end)
    end
  end

  defp shares(green, blue, red, yellow, violet),
    do: %Manameter{green: green, blue: blue, red: red, yellow: yellow, violet: violet}
end
