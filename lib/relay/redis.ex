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

  def room_key("room:" <> _ = room_key), do: room_key
  def room_key(room), do: "room:#{room}"

  def add_user_to_room(room, %{uuid: user_id, username: _}) do
    result = Redix.command(:redix, ["SADD", room_key(room), user_id])
    Logger.debug("Added user #{user_id} to room #{room}: #{inspect(result)}")
    result
  end

  def add_users_to_room(room, user_ids) when is_list(user_ids) do
    Redix.command(:redix, ["SADD", room_key(room)] ++ user_ids)
  end

  def remove_user_from_room(room, %{uuid: user_id, username: _}) do
    Redix.command(:redix, ["SREM", room_key(room), user_id])
  end

  def remove_users_from_room(room, user_ids) when is_list(user_ids) do
    Redix.command(:redix, ["SREM", room_key(room)] ++ user_ids)
  end

  def count_users_in_room(room) do
    Redix.command(:redix, ["SCARD", room_key(room)])
  end

  def list_active_rooms() do
    Enum.reduce(list_rooms_with_user_counts(), [], fn
      {room, user_count}, acc when user_count > 0 -> [room | acc]
      _, acc -> acc
    end)
  end

  def list_users_in_room(room) do
    case Redix.command(:redix, ["SMEMBERS", room_key(room)]) do
      {:ok, users} -> {:ok, users}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_rooms_with_users do
    Enum.reduce(list_rooms(), %{}, fn room, acc ->
      case list_users_in_room(room) do
        {:ok, users} -> Map.put(acc, room, users)
        {:error, _} -> acc
      end
    end)
  end

  def user_in_room?(room, %{uuid: user_id, username: _}) do
    case Redix.command(:redix, ["SISMEMBER", room_key(room), user_id]) do
      {:ok, 1} -> true
      _ -> false
    end
  end

  def get_user_count_for_room(room) do
    case Redix.command(:redix, ["SCARD", room_key(room)]) do
      {:ok, count} -> count
      {:error, _} -> 0
    end
  end

  def list_rooms() do
    Enum.map(scan_keys("room:*"), &String.replace_prefix(&1, "room:", ""))
  end

  def list_rooms_with_user_counts do
    Enum.reduce(list_rooms(), %{}, fn room, acc ->
      count = get_user_count_for_room(room)
      Map.put(acc, room, count)
    end)
  end

  defp scan_keys(pattern) do
    Enum.reduce_while([{"0", []}], [], fn {cursor, acc}, _ ->
      case Redix.command(:redix, ["SCAN", cursor, "MATCH", pattern]) do
        {:ok, ["0", found_keys]} -> {:halt, acc ++ found_keys}
        {:ok, [next_cursor, found_keys]} -> {:cont, {next_cursor, acc ++ found_keys}}
        {:error, _reason} -> {:halt, acc}
      end
    end)
  end
end
