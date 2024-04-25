defmodule RelayWeb.Presence do
  use Phoenix.Presence,
    otp_app: :relay,
    pubsub_server: Relay.PubSub
end
