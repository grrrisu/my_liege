defmodule MyLiege.Engine.ConfigTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Building, Config, LoadConfig, Manameter, Pentagon, Worker}

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
        LoadConfig.read!(Map.put(inputs, "place.farm.colour", 1))
      end
    end

    test "the lists written out in LoadConfig match the engine's" do
      assert LoadConfig.names() == %{
               types: Building.types(),
               goods: Building.products(),
               trainings: Worker.trainings(),
               relations: Pentagon.relations()
             }
    end

    test "a duplicate key fails" do
      assert_raise ArgumentError, ~r/duplicate key/, fn ->
        LoadConfig.parse!("key,value\na,1\na,2\n")
      end
    end
  end
end
