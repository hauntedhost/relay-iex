defmodule RelayWeb.Api.RootController do
  use RelayWeb, :controller

  def ping(conn, _) do
    conn
    |> put_status(:ok)
    |> json(%{boo: "👻"})
  end

  def health(conn, _) do
    conn
    |> put_status(:ok)
    |> json(%{ok: true})
  end
end
