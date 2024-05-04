defmodule RelayWeb.Presence do
  use Phoenix.Presence,
    otp_app: :relay,
    pubsub_server: Relay.PubSub

  require Logger
  alias Relay.Redis

  @pinned_rooms ~w(lobby qac)

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_metas("relay:" <> room, diff, _presences, state) do
    join_user_ids = Map.keys(diff.joins)
    leave_user_ids = Map.keys(diff.leaves)

    Redis.add_users_to_room(room, join_user_ids)
    Redis.remove_users_from_room(room, leave_user_ids)

    rooms_with_user_counts =
      Enum.reduce(@pinned_rooms, Redis.list_rooms_with_user_counts(), fn pinned_room, acc ->
        Map.put_new(acc, pinned_room, 0)
      end)

    room_names = Map.keys(rooms_with_user_counts)

    rooms_payload =
      Enum.map(rooms_with_user_counts, fn {room, user_count} ->
        [room, user_count]
      end)

    Logger.debug("broadcasting rooms_update to all rooms: #{inspect(rooms_with_user_counts)}")

    Enum.each(room_names, fn room ->
      RelayWeb.Endpoint.broadcast("relay:#{room}", "rooms_update", %{
        rooms: rooms_payload
      })
    end)

    {:ok, state}
  end
end
