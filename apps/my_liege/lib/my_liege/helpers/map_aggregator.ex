defmodule MyLiege.MapAggregator do
  def aggregate_map(%{} = map, input) do
    aggregate_map_func(
      map,
      input,
      &aggregate_map(&1, &2),
      fn current, input -> current + input end,
      fn input -> input end
    )
  end

  def aggregate_map_min_zero(map, input) do
    aggregate_map_func(
      map,
      input,
      &aggregate_map_min_zero(&1, &2),
      fn current, input ->
        if current + input < 0, do: 0, else: current + input
      end,
      fn input -> if input < 0, do: 0, else: input end
    )
  end

  def aggregate_map_func(map, nil, _, _, _), do: map

  def aggregate_map_func(map, input, aggregate_map_func, aggregate_fun, set_fun)
      when is_map(input) do
    Enum.reduce(input, map, fn {key, value}, acc ->
      case Map.get(acc, key) do
        nil -> Map.put(acc, key, set_fun.(value))
        submap when is_map(submap) -> Map.put(acc, key, aggregate_map_func.(submap, value))
        current -> Map.put(acc, key, aggregate_fun.(current, value))
      end
    end)
  end
end
