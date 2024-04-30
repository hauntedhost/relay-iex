defmodule RelayWeb.RelayChannel do
  use RelayWeb, :channel
  require Logger

  alias RelayWeb.Presence

  @impl true
  def join("relay:" <> room, %{"user" => %{"username" => username}} = payload, socket) do
    case validate_join(room, username) do
      :ok ->
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

      {:error, reason} ->
        {:error, %{reason: reason}}
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

  defp validate_join(room, username) do
    with :ok <- validate_room(room),
         :ok <- validate_username(username) do
      :ok
    end
  end

  defp validate_room(room) do
    if String.length(room) in 3..20 do
      :ok
    else
      {:error, "room length must be between 3 and 20 characters"}
    end
  end

  defp validate_username(username) do
    if String.length(username) in 3..20 do
      :ok
    else
      {:error, "username length must be between 3 and 20 characters"}
    end
  end
end
