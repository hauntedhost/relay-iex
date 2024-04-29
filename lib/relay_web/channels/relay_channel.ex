defmodule RelayWeb.RelayChannel do
  use RelayWeb, :channel
  require Logger

  alias RelayWeb.Presence

  @impl true
  def join("relay:" <> room, %{"user" => %{}} = payload, socket) do
    if authorized?(payload) do
      send(self(), :after_join)

      user = build_user(payload)

      response = %{
        event: "phx_join",
        user: user
      }

      socket =
        assign(socket, %{
          user: user,
          room: room
        })

      {:ok, response, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    %{room: room, user: user} = socket.assigns

    Relay.Redis.add_user_to_room(room, user)
    {:ok, _} = Presence.track(socket, user.uuid, user)

    broadcast(socket, "presence_state", Presence.list(socket))

    {:noreply, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (relay:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    user = get_user(socket)

    response =
      Map.merge(payload, %{
        event: "shout",
        user: user
      })

    broadcast(socket, "shout", response)
    {:noreply, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end

  defp build_user(%{"user" => user}) do
    %{
      uuid: user["uuid"],
      username: user["username"],
      online_at: System.system_time(:second)
    }
  end

  defp get_user(socket) do
    socket.assigns.user
  end
end
