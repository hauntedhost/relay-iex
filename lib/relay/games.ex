defmodule Relay.Games do
  alias Relay.Games.Player
  alias Relay.Redis

  defp player_key("player:" <> _ = player_key), do: player_key
  defp player_key(uuid), do: "player:#{uuid}"

  def add_player(%Player{uuid: uuid} = player) do
    Redis.command(["HSET", player_key(uuid) | Player.to_redis_fields_with_new_updated_at(player)])
  end

  def add_player!(player) do
    {:ok, player} = add_player(player)
    player
  end

  def get_player(player_key) when is_binary(player_key) do
    case Redis.command(["HGETALL", player_key(player_key)]) do
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

  def get_all_player_keys!, do: Redis.scan_keys!("player:*")

  def delete_player!(%Player{uuid: uuid}) do
    Redis.command!(["DEL", player_key(uuid)])
  end

  def delete_player!(player_key) when is_binary(player_key) do
    Redis.command!(["DEL", player_key(player_key)])
  end
end
