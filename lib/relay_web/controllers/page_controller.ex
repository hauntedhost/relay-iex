defmodule RelayWeb.PageController do
  use RelayWeb, :controller

  # def home(conn, _params) do
  #   # The home page is often custom made,
  #   # so skip the default app layout.
  #   render(conn, :home, layout: false)
  # end

  def home(conn, _) do
    text(conn, 200, "boo! 👻")
  end

  def health(conn, _) do
    text(conn, 200, "ok")
  end

  defp text(conn, status, text) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, text)
  end
end
