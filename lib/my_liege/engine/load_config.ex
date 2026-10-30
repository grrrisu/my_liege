defmodule MyLiege.Engine.LoadConfig do
  @moduledoc """
  Reads the designer's `key,value` CSV export and maps it to the configuration fields.
  Every value must be a whole number; anything else raises, so a bad export fails the build
  instead of being rounded.
  """

  alias MyLiege.Engine.Manameter

  require Logger

  @header "key,value"

  @doc "Reads the CSV at `path` and returns the configuration fields as a map."
  def load!(path) do
    inputs = path |> File.read!() |> parse!()

    config = %{
      birth_interval_weeks: fetch!(inputs, "birth_interval_weeks"),
      birth_min_food_left: fetch!(inputs, "birth_min_food_left"),
      starting_manameter: starting_manameter!(inputs),
      starting_farmers: fetch!(inputs, "starting_farmers"),
      starting_soldiers: fetch!(inputs, "starting_soldiers"),
      base_production: base_production(inputs),
      capacity: capacity(inputs),
      colour_factors: colour_factors(inputs),
      construction_weeks: fetch!(inputs, "construction_weeks"),
      mana_per_worker: mana_per_worker(inputs),
      manameter_points_per_week: fetch!(inputs, "manameter_points_per_week"),
      starting_food: fetch!(inputs, "starting_food"),
      starting_gold: fetch!(inputs, "starting_gold"),
      years_per_game: fetch!(inputs, "years_per_game"),
      food_eaten_per_worker: fetch!(inputs, "wheat_eaten_per_worker")
    }

    Logger.info(
      "config inputs: loaded #{map_size(inputs)} values from #{Path.relative_to_cwd(path)}"
    )

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

  @doc "Fetches a key, raising with the key's name if it is missing."
  def fetch!(values, key) do
    case Map.fetch(values, key) do
      {:ok, value} -> value
      :error -> raise ArgumentError, "config inputs: missing key #{inspect(key)}"
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

  defp starting_manameter!(inputs) do
    shares =
      for colour <- Manameter.colours(), do: {colour, fetch!(inputs, "manameter_start_#{colour}")}

    manameter = struct!(Manameter, shares)

    if Manameter.total(manameter) != Manameter.total_shares() do
      raise ArgumentError,
            "config inputs: manameter_start_* must sum to #{Manameter.total_shares()}, " <>
              "got #{Manameter.total(manameter)}"
    end

    manameter
  end

  defp base_production(inputs) do
    %{
      farm: fetch!(inputs, "wheat_per_farm_worker"),
      monastery: fetch!(inputs, "base_production_monastery"),
      watchtower: fetch!(inputs, "base_production_watchtower"),
      market: fetch!(inputs, "gold_per_market_worker"),
      tavern: fetch!(inputs, "base_production_tavern")
    }
  end

  defp capacity(inputs) do
    Map.new([:farm, :monastery, :watchtower, :market, :tavern], fn type ->
      {type, fetch!(inputs, "capacity_#{type}")}
    end)
  end

  defp colour_factors(inputs) do
    Map.new([:untrained, :trained], fn training ->
      {training,
       Map.new([:same, :neighbour, :opposite], fn relation ->
         {relation, fetch!(inputs, "factor_#{relation}_#{training}")}
       end)}
    end)
  end

  defp mana_per_worker(inputs) do
    Map.new([:untrained, :trained], fn training ->
      {training,
       %{
         building_colour: fetch!(inputs, "mana_building_#{training}"),
         own_colour: fetch!(inputs, "mana_own_#{training}")
       }}
    end)
  end
end
