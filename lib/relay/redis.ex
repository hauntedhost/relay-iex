defmodule Relay.Redis do
  @moduledoc """
  Provides functionality to interact with Redis.
  """
  require Logger

  def child_spec(_init_arg) do
    args = Application.get_env(:relay, Relay.Redis)
    Logger.info("Starting Redis with args: #{inspect(args)}")

    %{
      id: __MODULE__,
      start: {Redix, :start_link, [args]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end

  @rooms_key "rooms"

  def room_value("room:" <> room_value), do: room_value
  def room_value(room), do: room

  def add_room!(room) do
    Logger.debug("Adding ##{room_value(room)} to rooms")
    command!(["SADD", @rooms_key, room_value(room)])
  end

  def remove_room!(room) do
    Logger.debug("Removing ##{room_value(room)} from rooms")
    command!(["SREM", @rooms_key, room_value(room)])
  end

  def list_rooms!() do
    command!(["SMEMBERS", @rooms_key])
  end

  defp command!(command) do
    {:ok, result} = Redix.command(:redix, command)
    result
  end
end
