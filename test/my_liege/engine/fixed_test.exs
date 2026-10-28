defmodule MyLiege.Engine.FixedTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Fixed

  test "whole units become thousandths" do
    assert Fixed.from(24) == 24_000
  end
end
