defmodule MyLiege do
  alias Sim.Realm.CommandBus

  @moduledoc """
  MyLiege keeps the contexts that define your domain
  and business logic.
  """
  def create(name) do
    send_command({:admin, :create, name: name})
  end

  defp send_command(command) do
    CommandBus.dispatch(Game.CommandBus, command)
  end
end
