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
        # no builders and no travel, so tests about other rules stay independent of R2 sites
        builders_per_building: 0,
        travel_weeks: 0,
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
        # no grace period, so tests about other rules see taxes and demands from week 1
        grace_weeks: 0,
        training_threshold: 300,
        training_weeks: 4,
        demand_deadline_weeks: 8,
        demand_population_share: 100,
        demand_production_weeks: 8,
        spoilage_rates: %{food: 0, knowledge: 0, defence: 0, gold: 0, entertainment: 0},
        # bandits never set out and, if they do (no defence), never arrive, so tests about other
        # rules keep their gold; bandit tests set their own values
        bandit_threshold: 1_000_000,
        bandit_warning_weeks: 1_000_000,
        bandit_cover_weeks: 20,
        bandit_floor_step: 2,
        # the ratio is computed, but steps of 0 leave production alone, so tests about other
        # rules keep their food and defence; happiness tests set their own steps
        happiness_culture_per_worker: 1000,
        happiness_penalty_below: %{1 => 750, 2 => 500, 3 => 250},
        happiness_bonus_from: %{1 => 1250, 2 => 1750, 3 => 2500},
        happiness_steps: %{1 => 0, 2 => 0, 3 => 0}
      },
      overrides
    )
  end

  @doc "A new game without king's demands, for tests about other rules."
  def game_without_demands(config, seed), do: %{Game.new(config, seed) | demand_weeks: []}

  @doc "Runs `count` weeks, paying every due tax and delivering every demand. Returns `{reports, game}`."
  def run_weeks(game, count) do
    Enum.map_reduce(1..count//1, game, fn _, game ->
      game = if Game.tax_decision_due?(game), do: decide!(game), else: game
      game = if Game.demand_decision_due?(game), do: deliver!(game), else: game
      {:ok, report, game} = Game.run_week(game)
      {report, game}
    end)
  end

  defp deliver!(game) do
    {:ok, game} = Game.decide_demand(game, true)
    game
  end

  defp decide!(game) do
    {:ok, game} = Game.decide_tax(game, true)
    game
  end
end
