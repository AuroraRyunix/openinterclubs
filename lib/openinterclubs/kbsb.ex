defmodule OpenInterclubs.Kbsb do
  @moduledoc """
  Client for the public (anonymous) interclubs endpoints of the KBSB/FRBE API.

  See https://www.frbe-kbsb-ksb.be/docs. Responses are cached briefly in
  `OpenInterclubs.Kbsb.Cache` so browsing the UI doesn't hammer the API.
  """

  alias OpenInterclubs.Kbsb.Cache

  @doc "All clubs registered for interclubs, sorted by name."
  def clubs do
    with {:ok, clubs} <- get("/icclub") do
      {:ok, Enum.sort_by(clubs, &String.downcase(&1["name"] || ""))}
    end
  end

  @doc "One club including its teams and player list."
  def club(idclub), do: get("/icclub/#{idclub}")

  @doc "A series (division + index) with its teams and all rounds/encounters."
  def series(1, _index), do: get("/icresults/1")
  def series(division, index), do: get("/icresults/#{division}/#{index}")

  @doc "Playing halls of a club."
  def venue(idclub), do: get("/venue/#{idclub}")

  defp get(path) do
    Cache.fetch(path, fn ->
      case Req.get(base_url() <> path, [retry: :transient, max_retries: 2] ++ req_options()) do
        {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
        {:ok, %Req.Response{status: status}} -> {:error, {:http, status, path}}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  defp req_options, do: Application.get_env(:openinterclubs, :kbsb_req_options, [])

  defp base_url do
    Application.get_env(
      :openinterclubs,
      :kbsb_base_url,
      "https://www.frbe-kbsb-ksb.be/api/v1/interclubs/anon"
    )
  end
end
