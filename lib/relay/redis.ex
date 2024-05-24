defmodule Relay.Redis do
  @moduledoc """
  Provides functionality to interact with Redis.
  """
  require Logger

  def child_spec(_init_arg) do
    args = Application.get_env(:relay, Relay.Redis)
    Logger.info("Starting Redis with args: #{inspect(args)}")

    %{
      id: __MODULE__,
      start: {Redix, :start_link, [args]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end

  def command(command) do
    Redix.command(:redix, command)
  end

  def command!(command) do
    {:ok, result} = command(command)
    result
  end

  def scan_keys!(pattern), do: scan_keys!(pattern, "0", [])

  # Private

  defp scan_keys!(pattern, cursor, acc) do
    case command!(["SCAN", cursor, "MATCH", pattern]) do
      ["0", keys] -> acc ++ keys
      [new_cursor, keys] -> scan_keys!(pattern, new_cursor, acc ++ keys)
    end
  end
end
