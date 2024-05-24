defmodule RelayWeb.Presence do
  use Phoenix.Presence,
    otp_app: :relay,
    pubsub_server: Relay.PubSub

  require Logger

  alias Relay.Chats
  alias Relay.Games

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def fetch("game:" <> _, presences) do
    players = Map.new(Games.get_all_players(), fn player -> {player.uuid, player} end)

    for {player_uuid, %{metas: metas}} <- presences, into: %{} do
      {player_uuid, %{metas: metas, player: Map.get(players, player_uuid)}}
    end
  end

  @impl true
  def fetch(_topic, presences), do: presences

  @pinned_rooms MapSet.new(~w(lobby qac))

  @impl true
  def handle_metas("chat:" <> current_room, diff, _presences, state) do
    join_user_ids = Map.keys(diff.joins)
    leave_user_ids = Map.keys(diff.leaves)

    Logger.debug(
      "handle_metas for ##{current_room}: joins=#{inspect(join_user_ids)} leaves=#{inspect(leave_user_ids)}"
    )

    Chats.add_room!(current_room)
    redis_rooms = Chats.list_rooms!()

    # Add current_room to @pinned_rooms set
    pinned_rooms = MapSet.put(@pinned_rooms, current_room)

    rooms_with_pinned =
      pinned_rooms
      |> Enum.reduce(MapSet.new(redis_rooms), fn pinned_room, acc ->
        MapSet.put(acc, pinned_room)
      end)
      |> MapSet.to_list()

    Logger.debug("rooms: #{inspect(rooms_with_pinned)}")

    Task.start(fn ->
      # TODO: enqueue a job to remove inactive rooms
      active_rooms_payload =
        Enum.reduce(rooms_with_pinned, [], fn room, acc ->
          users = get_users_in_room(room)
          user_count = Enum.count(users)

          if user_count > 0 || MapSet.member?(pinned_rooms, room) do
            [[room, user_count] | acc]
          else
            acc
          end
        end)

      Logger.debug("broadcasting rooms_update to rooms: #{inspect(active_rooms_payload)}")

      Enum.each(active_rooms_payload, fn [room, _user_count] ->
        Logger.debug("broadcasting rooms_update to ##{room}")

        RelayWeb.Endpoint.broadcast("chat:#{room}", "rooms_update", %{
          rooms: active_rooms_payload
        })
      end)
    end)

    {:ok, state}
  end

  @impl true
  def handle_metas(_topic, _diff, _presences, state) do
    {:ok, state}
  end

  # Presence.list/1 returns user presence in this shape:
  # %{
  #   "ZfkOqYcl" => %{
  #     metas: [
  #       %{
  #         username: "veiled-frost-10",
  #         uuid: "ZfkOqYcl",
  #         online_at: 1_715_449_087,
  #         phx_ref: "F85_2yxtbtipowIB"
  #       },
  #       ...
  #     ]
  #   },
  #   ...
  # }
  #
  # For now we just take the first user presence from metas. In the future, if something like auth is introduced and
  # single users can be logged into multiple devices, we'll have to track each presence distinctly.
  defp get_users_in_room(room) do
    "chat:#{room}"
    |> list()
    |> Enum.map(fn {_uuid, %{metas: [user | _]}} ->
      user
    end)
  end
end
