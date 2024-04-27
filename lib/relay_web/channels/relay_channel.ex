defmodule RelayWeb.RelayChannel do
  use RelayWeb, :channel
  require Logger

  alias RelayWeb.Presence

  @impl true
  def join("relay:" <> room, %{"user" => %{}} = payload, socket) do
    Logger.info(%{
      event: "join",
      room: room,
      payload: payload,
      socket: socket
    })

    if authorized?(payload) do
      send(self(), :after_join)

      user = build_user(payload)

      response = %{
        user: user,
        event: "phx_join"
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
    Logger.info(%{
      event: ":after_join",
      socket: socket
    })

    # Track this user in the Presence data
    user = socket.assigns.user
    {:ok, _} = Presence.track(socket, user.uuid, user)

    broadcast(socket, "presence_state", Presence.list(socket))

    {:noreply, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (relay:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    Logger.info(%{
      event: "shout",
      payload: payload,
      socket: socket
    })

    user = get_user(socket)

    response =
      Map.merge(payload, %{
        user: user,
        event: "shout"
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
