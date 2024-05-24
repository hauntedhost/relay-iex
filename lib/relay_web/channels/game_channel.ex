defmodule RelayWeb.GameChannel do
  use RelayWeb, :channel
  require Logger

  alias Relay.Games
  alias Relay.Games.Player
  alias RelayWeb.Presence

  @impl true
  def join("game:" <> game, %{"player" => payload}, socket) do
    send(self(), :after_join_game)

    player = build_player(payload)

    response = %{
      event: "phx_join",
      player: player
    }

    socket =
      assign(socket, %{
        player: player,
        room: game
      })

    {:ok, response, socket}
  end

  @impl true
  def handle_info(:after_join_game, socket) do
    with %{player: player} <- socket.assigns,
         {:ok, _} <- Games.add_player(player),
         {:ok, _} <- Presence.track(socket, player.uuid, build_player_presence(player)),
         :ok <- broadcast(socket, "presence_state", Presence.list(socket)) do
      {:noreply, socket}
    end
  end

  @impl true
  def handle_in("player_update", %{"player_uuid" => uuid, "position" => position}, socket) do
    with {:ok, player} <- Games.get_player(uuid),
         {:ok, _} <- Games.add_player(%{player | position: position}) do
      :ok = broadcast(socket, "player_update", %{player_uuid: uuid, position: position})
      {:noreply, socket}
    end
  end

  defp build_player(%{"uuid" => uuid, "username" => username, "position" => position}) do
    %Player{
      uuid: uuid,
      username: username,
      position: position,
      joined_at: System.system_time(:second),
      updated_at: System.system_time(:second)
    }
  end

  defp build_player_presence(%Player{} = player) do
    player
    |> Map.from_struct()
    |> Map.take([:uuid, :username])
  end
end
