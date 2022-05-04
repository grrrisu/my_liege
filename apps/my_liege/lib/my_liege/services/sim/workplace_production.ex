defmodule MyLiege.Service.Sim.WorkplaceProduction do
  import MyLiege.MapAggregator

  alias MyLiege.Game.Workplace

  def workplaces_production(workplaces) do
    workplaces
    |> Enum.reduce({workplaces, [], %{}}, &reduce_production/2)
    |> workplace_event()
    |> inventory_event()
  end

  def reduce_production({_id, workplace}, {data, workplace_ids, outputs}) do
    {workplace, output} = Workplace.produce(workplace)
    {ids, workplaces} = replace_workplace(data, workplace_ids, workplace)
    {workplaces, ids, aggregate_map(outputs, output)}
  end

  def replace_workplace(data, ids, nil), do: {ids, data}

  def replace_workplace(data, ids, workplace) do
    {[workplace.id | ids], Map.replace(data, workplace.id, workplace)}
  end

  def workplace_event({data, ids, outputs}) when ids == [] do
    {data, [], outputs}
  end

  def workplace_event({data, ids, outputs}) do
    {data, [{:workplaces_updated, ids: ids}], outputs}
  end

  def inventory_event({data, events, outputs}) when map_size(outputs) == 0 do
    {data, events}
  end

  def inventory_event({data, events, outputs}) do
    {data, [{:command, {:sim, :add_inventory, outputs}} | events]}
  end
end
