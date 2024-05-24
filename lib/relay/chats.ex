defmodule Relay.Chats do
  alias Relay.Redis

  @rooms_key "rooms"

  def room_value("room:" <> room_value), do: room_value
  def room_value(room), do: room

  def add_room!(room) do
    Redis.command!(["SADD", @rooms_key, room_value(room)])
  end

  def remove_room!(room) do
    Redis.command!(["SREM", @rooms_key, room_value(room)])
  end

  def list_rooms!() do
    Redis.command!(["SMEMBERS", @rooms_key])
  end
end
