defmodule MyLiege.Engine.LoadConfig do
  @moduledoc """
  Reads the designer's `key,value` CSV export and maps it to the configuration fields.

  Keys are `group.item.attribute`, e.g. `place.farm.capacity`. Every value must be a whole
  number; anything else raises, so a bad export fails the build instead of being rounded.
  Every key is taken out of the inputs as it is read; a key left over at the end is unread
  and fails the build too, so unused keys can't pile up in the CSV.
  """

  alias MyLiege.Engine.{Manameter, Pentagon}
  alias MyLiege.Engine.Place.Blueprint

  require Logger

  @header "key,value"

  # the types that stand as buildings, each with its capacity
  @types Blueprint.building_types()
  # the types of the places whose workers make their good: the home places
  @good_types Blueprint.home_types()
  @goods Blueprint.goods()
  # written out here, not taken from Worker, which depends on Config at compile time; the
  # config test checks they match
  @trainings [:untrained, :trained]
  @levels [:level1, :level2, :level3]
  @lucks [:low, :mid, :high]
  # the chances of each luck are counts out of this many
  @luck_draws 10

  @doc false
  def names, do: %{trainings: @trainings}

  @doc "Reads the CSV at `path` and returns the configuration fields as a map."
  def load!(path) do
    inputs = path |> File.read!() |> parse!()
    config = read!(inputs)

    Logger.info(
      "config inputs: loaded #{map_size(inputs)} values from #{Path.relative_to_cwd(path)}"
    )

    config
  end

  @doc "Maps parsed inputs to the configuration fields. Raises on a missing or an unread key."
  def read!(inputs) do
    {config, unread} = fields().(inputs)

    if unread != %{} do
      raise ArgumentError,
            "config inputs: keys not read: #{unread |> Map.keys() |> Enum.sort() |> inspect()}"
    end

    config
  end

  @doc "Returns a map of key => integer. Raises on a bad header, line, value or duplicate key."
  def parse!(text) do
    [header | lines] =
      text
      |> String.split(["\r\n", "\n"])
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if header != @header do
      raise ArgumentError,
            "config inputs: expected header #{inspect(@header)}, got #{inspect(header)}"
    end

    Enum.reduce(lines, %{}, fn line, values ->
      {key, value} = parse_line!(line)

      if Map.has_key?(values, key) do
        raise ArgumentError, "config inputs: duplicate key #{inspect(key)}"
      end

      Map.put(values, key, value)
    end)
  end

  @doc "Takes a key out of `values`, returning `{value, rest}`. Raises with the key's name if it is missing."
  def take!(values, key) do
    case Map.pop(values, key) do
      {nil, _} -> raise ArgumentError, "config inputs: missing key #{inspect(key)}"
      found -> found
    end
  end

  defp parse_line!(line) do
    with [key, raw_value] <- String.split(line, ","),
         {value, ""} <- Integer.parse(raw_value) do
      {key, value}
    else
      _ -> raise ArgumentError, "config inputs: not a whole number in line #{inspect(line)}"
    end
  end

  defp fields do
    all(
      game_years: "game.years",
      start_farmers: "start.farmers",
      start_soldiers: "start.soldiers",
      start_food: "start.food",
      start_gold: "start.gold",
      manameter_start:
        Pentagon.colours()
        |> by(&"manameter.#{&1}.start_permille")
        |> then_apply(&manameter_start!/1),
      birth_interval_weeks: "birth.interval_weeks",
      birth_min_food_left: "birth.min_food_left",
      place_output_per_worker: by(@good_types, &"place.#{&1}.output_per_worker"),
      place_capacity: by(@types, &"place.#{&1}.capacity"),
      good_food_eaten_per_worker: "good.food.eaten_per_worker",
      good_spoilage: by(@goods, &"good.#{&1}.spoilage_permille"),
      efficiency:
        by(@trainings, fn training ->
          by(Pentagon.relations(), &"efficiency.#{training}.#{&1}_permille")
        end),
      mana_place_colour: "mana.place_colour",
      mana_good_colour: "mana.good_colour",
      manameter_points_per_week: "manameter.points_per_week_permille",
      training_min_share: "training.min_share_permille",
      training_weeks: "training.weeks",
      build_cost_gold: "build.cost_gold",
      build_work: "build.work",
      build_capacity: "build.capacity",
      book_work: "book.work",
      place_granary_food_spoilage: "place.granary.food_spoilage_permille",
      place_granary_culture_upkeep: "place.granary.culture_upkeep",
      place_granary_food_capacity: "place.granary.food_capacity",
      way_plough_work: "way.plough.work",
      way_plough_capacity: "way.plough.capacity",
      way_plough_bonus: "way.plough.bonus_permille",
      way_plough_2_work: "way.plough_2.work",
      way_plough_2_capacity: "way.plough_2.capacity",
      way_plough_2_bonus: "way.plough_2.bonus_permille",
      way_books: by(Blueprint.config_book_types(), &"way.#{&1}.books"),
      way_grain_trade_capacity: "way.grain_trade.capacity",
      way_grain_trade_gold_per_week: "way.grain_trade.gold_per_week",
      way_grain_trade_food_per_week: "way.grain_trade.food_per_week",
      way_grain_trade_travel_weeks: "way.grain_trade.travel_weeks",
      # the party rows depend on max_party: read them before max_party is taken
      way_hunting_party: &hunting_parties!/1,
      way_hunting_max_party: "way.hunting.max_party",
      way_hunting_travel_weeks: "way.hunting.travel_weeks",
      way_hunting_haul_weeks: "way.hunting.haul_weeks",
      way_hunting_food_per_week: "way.hunting.food_per_week",
      way_hunting_luck: by(@lucks, &"way.hunting.luck_#{&1}_permille"),
      king_suspicion: by(@lucks, &"king.suspicion.#{&1}"),
      king_suspicion_decay: "king.suspicion.decay",
      king_suspicion_threshold: "king.suspicion.threshold",
      travel_weeks: "travel.weeks",
      king_grace_weeks: "king.grace_weeks",
      king_misses_forgiven: "king.misses_forgiven",
      king_tax_per_worker: "king.tax.per_worker",
      king_tax_interval_weeks: "king.tax.interval_weeks",
      king_tax_count_lead_weeks: "king.tax.count_lead_weeks",
      king_demand_deadline_weeks: "king.demand.deadline_weeks",
      king_demand_population_share: "king.demand.population_share_permille",
      king_demand_production_weeks: "king.demand.production_weeks",
      bandit_threshold: "bandit.threshold",
      bandit_warning_weeks: "bandit.warning_weeks",
      bandit_cover_weeks: "bandit.cover_weeks",
      bandit_floor_step: "bandit.floor_step",
      happiness_need_per_worker: "happiness.need_per_worker_permille",
      happiness_penalty_below: by(@levels, &"happiness.#{&1}.penalty_below_permille"),
      happiness_bonus_from: by(@levels, &"happiness.#{&1}.bonus_from_permille"),
      happiness_change: by(@levels, &"happiness.#{&1}.change_permille")
    )
  end

  # A reader takes inputs and returns {value, the inputs it didn't read}; a key is a reader too.
  defp reader(key) when is_binary(key), do: &take!(&1, key)
  defp reader(reader) when is_function(reader, 1), do: reader

  # reads every {name, reader or key} into a map of name => value
  defp all(pairs) do
    fn inputs ->
      Enum.reduce(pairs, {%{}, inputs}, fn {name, field}, {values, rest} ->
        {value, rest} = reader(field).(rest)
        {Map.put(values, name, value), rest}
      end)
    end
  end

  # reads one value per item: `key_or_reader.(item)` gives its key or reader
  defp by(items, key_or_reader), do: items |> Enum.map(&{&1, key_or_reader.(&1)}) |> all()

  defp then_apply(reader, fun) do
    fn inputs ->
      {value, rest} = reader.(inputs)
      {fun.(value), rest}
    end
  end

  # `way.hunting.party<n>.<luck>` for every party size n from 1 to `way.hunting.max_party`;
  # each size's counts must sum to @luck_draws
  defp hunting_parties!(inputs) do
    {max_party, _rest} = take!(inputs, "way.hunting.max_party")

    sizes = 1..max_party//1 |> Enum.to_list()

    {parties, rest} =
      by(sizes, fn size -> by(@lucks, &"way.hunting.party#{size}.#{&1}") end).(inputs)

    for {size, counts} <- parties, counts |> Map.values() |> Enum.sum() != @luck_draws do
      raise ArgumentError,
            "config inputs: way.hunting.party#{size}.* must sum to #{@luck_draws}, " <>
              "got #{counts |> Map.values() |> Enum.sum()}"
    end

    {parties, rest}
  end

  defp manameter_start!(shares) do
    manameter = struct!(Manameter, shares)

    if Manameter.total(manameter) != Manameter.total_shares() do
      raise ArgumentError,
            "config inputs: manameter.<colour>.start_permille must sum to " <>
              "#{Manameter.total_shares()}, got #{Manameter.total(manameter)}"
    end

    manameter
  end
end
