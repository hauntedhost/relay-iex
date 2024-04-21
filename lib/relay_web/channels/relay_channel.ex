defmodule RelayWeb.RelayChannel do
  use RelayWeb, :channel

  @impl true
  def join("relay:lobby", payload, socket) do
    if authorized?(payload) do
      send(self(), :after_join)
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    response = %{
      user: socket.join_ref,
      event: "joined",
      message: ""
    }

    broadcast(socket, "joined", response)
    {:noreply, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (relay:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    response =
      Map.merge(payload, %{
        user: socket.ref,
        event: "shout"
      })

    broadcast(socket, "shout", response)
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
