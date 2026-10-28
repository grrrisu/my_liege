defmodule MyLiege.Engine.ConfigTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Config, LoadConfig, Manameter}

  describe "loading config inputs" do
    test "the CSV loads into a complete configuration with a full Manameter" do
      config = Config.from_csv()

      assert %Config{} = config
      assert Manameter.total(config.starting_manameter) == Manameter.total_shares()
    end

    test "values are read by key, in any row order" do
      assert LoadConfig.parse!("key,value\nb,2\na,1\n") == %{"a" => 1, "b" => 2}
    end

    test "a value that is not a whole number fails" do
      assert_raise ArgumentError, ~r/not a whole number/, fn ->
        LoadConfig.parse!("key,value\nfactor_same_untrained,0.8\n")
      end
    end

    test "a missing key fails, naming the key" do
      assert_raise ArgumentError, ~r/missing key "capacity_farm"/, fn ->
        LoadConfig.fetch!(%{}, "capacity_farm")
      end
    end

    test "a duplicate key fails" do
      assert_raise ArgumentError, ~r/duplicate key/, fn ->
        LoadConfig.parse!("key,value\na,1\na,2\n")
      end
    end
  end
end
