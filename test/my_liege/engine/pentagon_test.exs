defmodule MyLiege.Engine.PentagonTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Manameter, Pentagon}

  @neighbours [green: :yellow, yellow: :blue, blue: :red, red: :violet, violet: :green]
  @opposites [green: :blue, green: :red, yellow: :red, yellow: :violet, blue: :violet]

  test "pentagon order: Growth – Wealth – Wisdom – Strength – Culture" do
    assert Manameter.colours() == [:green, :yellow, :blue, :red, :violet]
  end

  test "a colour is the same as itself" do
    for colour <- Manameter.colours(), do: assert(Pentagon.relation(colour, colour) == :same)
  end

  test "all ten pairs are neighbours or opposites, in both directions" do
    assert length(@neighbours ++ @opposites) == 10

    for {a, b} <- @neighbours do
      assert Pentagon.relation(a, b) == :neighbour, "#{a}–#{b}"
      assert Pentagon.relation(b, a) == :neighbour, "#{b}–#{a}"
    end

    for {a, b} <- @opposites do
      assert Pentagon.relation(a, b) == :opposite, "#{a}–#{b}"
      assert Pentagon.relation(b, a) == :opposite, "#{b}–#{a}"
    end
  end
end
