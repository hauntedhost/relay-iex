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
    Relay.Redis.add_users_to_room(room, join_user_ids)

    leave_user_ids = Map.keys(diff.leaves)
    Relay.Redis.remove_users_from_room(room, leave_user_ids)

    rooms = Relay.Redis.list_active_rooms()

    Logger.debug("broadcasting rooms_update to all rooms: #{inspect(rooms)}")

    Enum.each(rooms, fn room ->
      RelayWeb.Endpoint.broadcast("relay:#{room}", "rooms_update", %{
        rooms: rooms
      })
    end)

    {:ok, state}
  end
end
