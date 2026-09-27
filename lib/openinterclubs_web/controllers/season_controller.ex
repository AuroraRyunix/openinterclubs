defmodule OpenInterclubsWeb.SeasonController do
  use OpenInterclubsWeb, :controller

  alias OpenInterclubs.Season.Archive

  @doc "Switch the season shown on all pages (kept in the session)."
  def select(conn, %{"season" => season}) do
    season = if season in Archive.seasons(), do: season, else: nil

    conn
    |> put_session(:season, season)
    |> redirect(to: back(conn))
  end

  # Back to the page the user came from, if it's on this site.
  defp back(conn) do
    with [ref | _] <- get_req_header(conn, "referer"),
         %URI{path: "/" <> _ = path, query: q} <- URI.parse(ref),
         false <- String.starts_with?(path, "/seizoen") do
      if q, do: path <> "?" <> q, else: path
    else
      _ -> "/"
    end
  end
end
