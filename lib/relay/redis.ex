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

  def command(command) do
    Redix.command(:redix, command)
  end

  defp command!(command) do
    {:ok, result} = command(command)
    result
  end

  # Game

  defmodule Player do
    @derive Jason.Encoder
    @enforce_keys [:uuid, :username, :position, :updated_at]
    defstruct [:uuid, :username, :position, :updated_at, :joined_at]

    def from_redis_fields(fields) when is_list(fields) do
      %{
        "uuid" => uuid,
        "username" => username,
        "position" => position,
        "joined_at" => joined_at,
        "updated_at" => updated_at
      } =
        fields
        |> Enum.chunk_every(2)
        |> Map.new(fn [k, v] -> {k, v} end)

      %__MODULE__{
        uuid: uuid,
        username: username,
        position: decode_position!(position),
        joined_at: String.to_integer(joined_at),
        updated_at: String.to_integer(updated_at)
      }
    end

    def to_redis_fields(%__MODULE__{} = player) do
      [
        "uuid",
        player.uuid,
        "username",
        player.username,
        "position",
        inspect(player.position),
        "joined_at",
        player.joined_at,
        "updated_at",
        player.updated_at
      ]
    end

    def to_redis_fields_with_new_updated_at(player) do
      to_redis_fields(%{player | updated_at: System.system_time(:second)})
    end

    defp decode_position!(none) when none in [nil, "nil"], do: nil
    defp decode_position!(position), do: Jason.decode!(position)
  end

  defp player_key("player:" <> _ = player_key), do: player_key
  defp player_key(uuid), do: "player:#{uuid}"

  def add_player(%Player{uuid: uuid} = player) do
    Logger.debug("Updating player: #{inspect(player)}")
    command(["HSET", player_key(uuid) | Player.to_redis_fields_with_new_updated_at(player)])
  end

  def add_player!(player) do
    {:ok, player} = add_player(player)
    player
  end

  def get_player(player_key) when is_binary(player_key) do
    case command(["HGETALL", player_key(player_key)]) do
      {:ok, [_ | _] = fields} -> {:ok, Player.from_redis_fields(fields)}
      {:ok, []} -> {:error, :not_found}
      {:error, _} = error -> error
    end
  end

  def get_all_players do
    Enum.reduce(get_all_player_keys!(), [], fn player_key, acc ->
      case get_player(player_key) do
        {:ok, player} -> [player | acc]
        {:error, _} -> acc
      end
    end)
  end

  def get_all_player_keys!, do: scan_keys!("player:*")

  def delete_player!(%Player{uuid: uuid} = player) do
    Logger.debug("Deleting player: #{inspect(player)}")
    command!(["DEL", player_key(uuid)])
  end

  def delete_player!(player_key) when is_binary(player_key) do
    Logger.debug("Deleting player: #{player_key}")
    command!(["DEL", player_key(player_key)])
  end

  defp scan_keys!(pattern), do: scan_keys!(pattern, "0", [])

  defp scan_keys!(pattern, cursor, acc) do
    case command!(["SCAN", cursor, "MATCH", pattern]) do
      ["0", keys] -> acc ++ keys
      [new_cursor, keys] -> scan_keys!(pattern, new_cursor, acc ++ keys)
    end
  end

  # Chat

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
end
