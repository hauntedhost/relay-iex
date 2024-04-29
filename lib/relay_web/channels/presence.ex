defmodule RelayWeb.Presence do
  use Phoenix.Presence,
    otp_app: :relay,
    pubsub_server: Relay.PubSub

  require Logger

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_metas("relay:" <> room, diff, _presences, state) do
    join_user_ids = Map.keys(diff.joins)
    leave_user_ids = Map.keys(diff.leaves)

    Relay.Redis.add_users_to_room(room, join_user_ids)
    Relay.Redis.remove_users_from_room(room, leave_user_ids)

    rooms = Relay.Redis.list_rooms_with_user_counts()

    room_names_with_counts =
      Enum.map(rooms, fn {room, user_count} ->
        [room, user_count]
      end)

    room_names = Map.keys(rooms)

    Logger.debug("broadcasting rooms_update to all rooms: #{inspect(rooms)}")

    Enum.each(room_names, fn room ->
      RelayWeb.Endpoint.broadcast("relay:#{room}", "rooms_update", %{
        rooms: room_names_with_counts
      })
    end)

    {:ok, state}
  end
end
