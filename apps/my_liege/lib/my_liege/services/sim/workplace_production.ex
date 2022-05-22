defmodule MyLiege.Service.Sim.WorkplaceProduction do
  alias MyLiege.Game.Workplace

  @type workplaces :: %{integer => %Workplace{}}
  @type event :: {atom, any} | {:command, {atom, keyword}}

  @spec workplaces_production(workplaces) :: {workplaces, [event]}
  def workplaces_production(workplaces) do
    workplaces
    |> Enum.reduce({[], []}, &production_events/2)
    |> replace_workplaces(workplaces)
  end

  def production_events({_id, workplace}, {changed_workplaces, events}) do
    case produce(workplace) do
      {nil, new_events} -> {changed_workplaces, new_events ++ events}
      {workplace, new_events} -> {[workplace | changed_workplaces], new_events ++ events}
    end
  end

  def replace_workplaces({[], events}, all_workplaces), do: {all_workplaces, events}

  def replace_workplaces({changed_workplaces, events}, all_workplaces) do
    workplaces =
      Enum.reduce(changed_workplaces, all_workplaces, fn workplace, all_workplaces ->
        Map.replace(all_workplaces, workplace.id, workplace)
      end)

    ids = Enum.map(changed_workplaces, & &1.id)
    {workplaces, [{:workplaces_updated, ids: ids}] ++ events}
  end

  def produce(%Workplace{pawn: nil}), do: {nil, []}

  def produce(%Workplace{} = workplace) do
    if Workplace.has_material?(workplace) do
      next_step(workplace)
    else
      [{material, _amount}] =
        workplace
        |> Workplace.needed_material()
        |> Enum.take(1)

      {nil, [{:command, {:user, :transport_to_workplace, goods: %{material => 1}}}]}
    end
  end

  defp next_step(
         %Workplace{
           type: :construction_site,
           inventory: %{manpower: x},
           input: %{manpower: x}
         } = construction_site
       ) do
    {Workplace.construct_site(construction_site),
     [{:command, {:user, :remove_pawn_from_workplace, workplace_id: construction_site.id}}]}
  end

  defp next_step(
         %Workplace{type: _factory, inventory: %{manpower: x}, input: %{manpower: x}} = factory
       ) do
    {factory, output} = Workplace.produce_output(factory)
    {factory, [{:command, {:sim, :add_inventory, output}}]}
  end

  defp next_step(%Workplace{} = factory) do
    {Workplace.inc_manpower(factory), []}
  end
end
