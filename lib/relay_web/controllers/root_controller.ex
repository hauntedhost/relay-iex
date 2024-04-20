defmodule RelayWeb.RootController do
  use RelayWeb, :controller

  def ping(conn, _) do
    send_resp_text(conn, 200, "boo! 👻")
  end

  def health(conn, _) do
    send_resp_text(conn, 200, ":ok")
  end

  defp send_resp_text(conn, status, text) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, text)
  end
end
