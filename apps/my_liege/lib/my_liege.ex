defmodule MyLiege do
  alias Sim.Realm.{CommandBus, Data, SimulationLoop}

  @moduledoc """
  MyLiege keeps the contexts that define your domain
  and business logic.
  """
  def create(name) do
    send_command({:admin, :create, name: name})
  end

  def board_exists?() do
    not (get_data() |> is_nil())
  end

  def get_data() do
    Data.get_data(MyLiege.Game.Data)
  end

  def tick() do
    send_command({:sim, :tick})
  end

  def start_sim() do
    send_command({:admin, :start_sim})
  end

  def stop_sim() do
    send_command({:admin, :stop_sim})
  end

  def started?() do
    SimulationLoop.running?(MyLiege.Game.SimulationLoop)
  end

  def add_pawn_to_workplace(id) do
    send_command({:user, :add_pawn_to_workplace, workplace_id: id})
  end

  def remove_pawn_from_workplace(id) do
    send_command({:user, :remove_pawn_from_workplace, workplace_id: id})
  end

  def send_command(command) do
    :ok = CommandBus.dispatch(MyLiege.Game.CommandBus, command)
  end
end
