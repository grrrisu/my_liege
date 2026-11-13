defmodule MyLiege.EngineFixtures do
  @moduledoc "Explicit engine configuration for tests, independent of the designer's CSV."

  alias MyLiege.Engine.{Config, Game, Manameter}
  alias MyLiege.Engine.Place.{Blueprint, Building, Project}

  def config(overrides \\ []) do
    struct!(
      %Config{
        birth_interval_weeks: 2,
        birth_min_food_left: 1,
        manameter_start: %Manameter{green: 800, blue: 50, red: 100, yellow: 50, violet: 0},
        start_farmers: 1,
        start_soldiers: 1,
        place_output_per_worker: %{farm: 9, monastery: 3, watchtower: 3, market: 3, tavern: 3},
        place_capacity: %{
          farm: 4,
          monastery: 4,
          watchtower: 4,
          market: 4,
          tavern: 4,
          guildhouse: 1
        },
        efficiency: %{
          untrained: %{same: 1000, neighbour: 800, opposite: 500},
          trained: %{same: 1250, neighbour: 600, opposite: 300}
        },
        build_weeks: 2,
        build_cost_gold: 30,
        # no builders and no travel, so tests about other rules stay independent of R2 sites
        build_builders: 0,
        travel_weeks: 0,
        mana: %{
          untrained: %{place_colour: 2, worker_colour: 1},
          trained: %{place_colour: 1, worker_colour: 2}
        },
        manameter_points_per_week: 3,
        start_food: 24,
        start_gold: 100,
        game_years: 3,
        good_food_eaten_per_worker: 3,
        king_tax_per_worker: 10,
        king_tax_interval_weeks: 24,
        king_tax_count_lead_weeks: 4,
        king_misses_forgiven: 1,
        # no grace period, so tests about other rules see taxes and demands from week 1
        king_grace_weeks: 0,
        training_min_share: 300,
        training_weeks: 4,
        king_demand_deadline_weeks: 8,
        king_demand_population_share: 100,
        king_demand_production_weeks: 8,
        good_spoilage: %{food: 0, knowledge: 0, defence: 0, gold: 0, culture: 0},
        # bandits never set out and, if they do (no defence), never arrive, so tests about other
        # rules keep their gold; bandit tests set their own values
        bandit_threshold: 1_000_000,
        bandit_warning_weeks: 1_000_000,
        bandit_cover_weeks: 20,
        bandit_floor_step: 2,
        # the ratio is computed, but steps of 0 leave production alone, so tests about other
        # rules keep their food and defence; happiness tests set their own steps
        happiness_need_per_worker: 1000,
        happiness_penalty_below: %{level1: 750, level2: 500, level3: 250},
        happiness_bonus_from: %{level1: 1250, level2: 1750, level3: 2500},
        happiness_change: %{level1: 0, level2: 0, level3: 0}
      },
      overrides
    )
  end

  @doc "A building of `type` with id `id`."
  def new_building(id, type), do: %Building{id: id, blueprint: Blueprint.fetch!(type)}

  @doc "A site with id `id` that gives a building of `type`, target 2 unless `fields` say otherwise."
  def new_site(id, type, fields \\ []) do
    site = %Project{
      id: id,
      blueprint: Project.site_blueprint(),
      target: 2,
      gives: {:building, type}
    }

    struct!(site, fields)
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
