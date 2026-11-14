defmodule MyLiege.Engine.ConfigTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Config, LoadConfig, Manameter, Worker}
  alias MyLiege.Engine.Place.Blueprint

  describe "loading config inputs" do
    test "the CSV loads into a complete configuration with a full Manameter" do
      config = Config.from_csv()

      assert %Config{} = config
      assert Manameter.total(config.manameter_start) == Manameter.total_shares()
    end

    test "values are read by key, in any row order" do
      assert LoadConfig.parse!("key,value\nb,2\na,1\n") == %{"a" => 1, "b" => 2}
    end

    test "a value that is not a whole number fails" do
      assert_raise ArgumentError, ~r/not a whole number/, fn ->
        LoadConfig.parse!("key,value\nefficiency.untrained.same_permille,0.8\n")
      end
    end

    test "a missing key fails, naming the key" do
      assert_raise ArgumentError, ~r/missing key "place.farm.capacity"/, fn ->
        LoadConfig.take!(%{}, "place.farm.capacity")
      end
    end

    test "a key that is not read fails, naming the key" do
      inputs = "priv/balance_inputs.csv" |> File.read!() |> LoadConfig.parse!()

      assert_raise ArgumentError, ~r/keys not read: \["place.farm.colour"\]/, fn ->
        inputs |> Map.put("place.farm.colour", 1) |> LoadConfig.read!()
      end
    end

    test "R17: hunting party counts are read for sizes 1 to max_party and must sum to 10" do
      inputs = "priv/balance_inputs.csv" |> File.read!() |> LoadConfig.parse!()
      config = LoadConfig.read!(inputs)

      assert Map.keys(config.way_hunting_party) == Enum.to_list(1..config.way_hunting_max_party)

      assert_raise ArgumentError, ~r/way.hunting.party2.\* must sum to 10, got 11/, fn ->
        inputs |> Map.update!("way.hunting.party2.low", &(&1 + 1)) |> LoadConfig.read!()
      end

      assert_raise ArgumentError, ~r/keys not read: \["way.hunting.party4/, fn ->
        inputs |> Map.put("way.hunting.max_party", 3) |> LoadConfig.read!()
      end
    end

    test "the lists written out in LoadConfig match the engine's" do
      assert LoadConfig.names() == %{trainings: Worker.trainings()}
    end

    test "every building type has its place.<type>.* keys" do
      keys = "priv/balance_inputs.csv" |> File.read!() |> LoadConfig.parse!() |> Map.keys()

      for type <- Blueprint.building_types() do
        assert Enum.any?(keys, &String.starts_with?(&1, "place.#{type}.")), "no keys for #{type}"
      end
    end

    test "a duplicate key fails" do
      assert_raise ArgumentError, ~r/duplicate key/, fn ->
        LoadConfig.parse!("key,value\na,1\na,2\n")
      end
    end
  end
end
