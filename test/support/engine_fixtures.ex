defmodule MyLiege.EngineFixtures do
  @moduledoc "Explicit engine configuration for tests, independent of the designer's CSV."

  alias MyLiege.Engine.{Config, Game, Manameter}

  def config(overrides \\ []) do
    struct!(
      %Config{
        birth_interval_weeks: 2,
        birth_min_food_left: 1,
        starting_manameter: %Manameter{green: 800, blue: 50, red: 100, yellow: 50, violet: 0},
        starting_farmers: 1,
        starting_soldiers: 1,
        base_production: %{farm: 9, monastery: 3, watchtower: 3, market: 3, tavern: 3},
        capacity: %{farm: 4, monastery: 4, watchtower: 4, market: 4, tavern: 4, guildhouse: 1},
        colour_factors: %{
          untrained: %{same: 1000, neighbour: 800, opposite: 500},
          trained: %{same: 1250, neighbour: 600, opposite: 300}
        },
        construction_weeks: 2,
        build_cost_gold: 30,
        mana_per_worker: %{
          untrained: %{building_colour: 2, own_colour: 1},
          trained: %{building_colour: 1, own_colour: 2}
        },
        manameter_points_per_week: 3,
        starting_food: 24,
        starting_gold: 100,
        years_per_game: 3,
        food_eaten_per_worker: 3,
        tax_per_worker: 10,
        tax_interval_weeks: 24,
        tax_count_lead_weeks: 4,
        tax_misses_forgiven: 1,
        training_threshold: 300,
        training_weeks: 4,
        demand_deadline_weeks: 8,
        demand_population_share: 100,
        demand_production_weeks: 8,
        spoilage_rates: %{food: 0, knowledge: 0, defence: 0, gold: 0, entertainment: 0}
      },
      overrides
    )
  end

  @doc "A new game without king's demands, for tests about other rules."
  def game_without_demands(config, seed), do: %{Game.new(config, seed) | demand_weeks: []}

  @doc "Runs `count` weeks, paying every due tax and delivering every demand. Returns `{reports, game}`."
  def run_weeks(game, count, config) do
    Enum.map_reduce(1..count//1, game, fn _, game ->
      game = if Game.tax_decision_due?(game, config), do: decide!(game, config), else: game
      game = if Game.demand_decision_due?(game), do: deliver!(game), else: game
      {:ok, report, game} = Game.run_week(game, config)
      {report, game}
    end)
  end

  defp deliver!(game) do
    {:ok, game} = Game.decide_demand(game, true)
    game
  end

  defp decide!(game, config) do
    {:ok, game} = Game.decide_tax(game, true, config)
    game
  end
end
