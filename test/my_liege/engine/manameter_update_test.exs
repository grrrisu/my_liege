defmodule MyLiege.Engine.ManameterUpdateTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Config, Manameter, ManameterUpdate}

  @no_mana %{green: 0, blue: 0, red: 0, yellow: 0, violet: 0}

  describe "R4: Manameter update" do
    setup do
      %{config: %Config{}}
    end

    test "10 points: removed by current shares, added by the week's mana", %{config: config} do
      mana = %{@no_mana | green: 15, red: 5}

      assert_shares(
        ManameterUpdate.update(config.starting_manameter, mana, config),
        %{green: 79.5, blue: 4.5, red: 11.5, yellow: 4.5, violet: 0.0}
      )
    end

    test "a colour with no share gains when it makes mana", %{config: config} do
      mana = %{@no_mana | violet: 3}

      assert_shares(
        ManameterUpdate.update(config.starting_manameter, mana, config),
        %{green: 72.0, blue: 4.5, red: 9.0, yellow: 4.5, violet: 10.0}
      )
    end

    test "the Manameter stays unchanged in a week without mana", %{config: config} do
      assert ManameterUpdate.update(config.starting_manameter, @no_mana, config) ==
               config.starting_manameter
    end

    test "the points per week come from the configuration", %{config: config} do
      config = %{config | manameter_points_per_week: 20}
      mana = %{@no_mana | red: 1}

      assert_shares(
        ManameterUpdate.update(config.starting_manameter, mana, config),
        %{green: 64.0, blue: 4.0, red: 28.0, yellow: 4.0, violet: 0.0}
      )
    end

    test "shares always sum to 100 and never go below 0", %{config: config} do
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
      |> Enum.reduce(config.starting_manameter, fn mana, manameter ->
        manameter = ManameterUpdate.update(manameter, mana, config)
        shares = Enum.map(Manameter.colours(), &Map.fetch!(manameter, &1))

        assert_in_delta Enum.sum(shares), 100, 1.0e-9
        assert Enum.all?(shares, &(&1 >= 0))
        manameter
      end)
    end
  end

  defp assert_shares(manameter, expected_shares) do
    for {colour, expected_share} <- expected_shares do
      assert_in_delta Map.fetch!(manameter, colour), expected_share, 1.0e-9
    end
  end
end
