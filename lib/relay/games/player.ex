defmodule Relay.Games.Player do
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
