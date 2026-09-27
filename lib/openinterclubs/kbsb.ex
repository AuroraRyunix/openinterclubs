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
  def series(division, index) do
    path = if division == 1, do: "/icresults/1", else: "/icresults/#{division}/#{index}"

    with {:ok, s} <- get(path), do: {:ok, OpenInterclubs.Schedule.complete(s)}
  end

  # ---- authenticated (club) endpoints ------------------------------------

  @doc """
  Log in with a KBSB member login. Returns `{:ok, token, idnumber}`;
  `idnumber` is nil when the KBSB doesn't return it. Nothing is stored here.
  """
  def login(user, password) do
    user = String.trim(user)

    with {:ok, body} <- post("/api/v1/member/login", %{email: user, password: password}),
         {:ok, token} <- extract_token(body) do
      idnumber =
        cond do
          is_list(body) and Enum.any?(body, &is_integer/1) -> Enum.find(body, &is_integer/1)
          match?({_, ""}, Integer.parse(user)) -> String.to_integer(user)
          true -> nil
        end

      {:ok, token, idnumber}
    end
  end

  @doc "The club a member belongs to (public member record)."
  def member_club(idnumber) when is_integer(idnumber) do
    case Req.get(
           root_url() <> "/api/v1/member/anon/member/#{idnumber}",
           [retry: false] ++ req_options()
         ) do
      {:ok, %Req.Response{status: 200, body: %{"idclub" => c}}} when is_integer(c) and c > 0 ->
        {:ok, c}

      _ ->
        :error
    end
  end

  def member_club(_), do: :error

  @roles ~w(InterclubAdmin InterclubCaptain ClubAdmin)

  @doc """
  Whether the token's owner holds a club role for `idclub`, per the KBSB
  (`clubs/clb/club/{idclub}/access/{role}`: true, or 403 when not).
  Superusers pass for every club. Only asked for the club being viewed.
  """
  def club_access?(token, idclub) when is_binary(token) and is_integer(idclub) do
    Enum.any?(@roles, fn role ->
      url = root_url() <> "/api/v1/clubs/clb/club/#{idclub}/access/#{role}"

      match?(
        {:ok, %Req.Response{status: 200, body: true}},
        Req.get(url, [auth: {:bearer, token}, retry: false] ++ req_options())
      )
    end)
  end

  def club_access?(_, _), do: false

  @doc "Series of a club as the club sees them, lineups included (needs a token)."
  def club_series(token, idclub, round) do
    url = root_url() <> "/api/v1/interclubs/clb/icseries"

    case Req.get(
           url,
           [params: [idclub: idclub, round: round], auth: {:bearer, token}, retry: false] ++
             req_options()
         ) do
      {:ok, %Req.Response{status: 200, body: body}} when is_list(body) -> {:ok, body}
      {:ok, %Req.Response{status: s}} when s in [401, 403] -> {:error, :unauthorized}
      {:ok, %Req.Response{status: s, body: b}} -> {:error, {:http, s, b}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Let the KBSB validate a club's planning. Returns `{:ok, errors}`."
  def validate_planning(token, planning) do
    case put("/api/v1/interclubs/clb/icplanningvalidate", token, planning) do
      {:ok, errors} when is_list(errors) -> {:ok, errors}
      {:ok, _} -> {:ok, []}
      error -> error
    end
  end

  @doc "Save a club's planning (lineups) for a round."
  def save_planning(token, planning),
    do: put("/api/v1/interclubs/clb/icplanning", token, planning) |> ok()

  @doc "Save results of one or more encounters."
  def save_results(token, results),
    do: put("/api/v1/interclubs/clb/icresults", token, %{results: results}) |> ok()

  defp ok({:ok, _}), do: :ok
  defp ok(error), do: error

  defp put(path, token, body) do
    case Req.put(
           root_url() <> path,
           [json: body, auth: {:bearer, token}, retry: false] ++ req_options()
         ) do
      {:ok, %Req.Response{status: s, body: body}} when s in 200..299 -> {:ok, body}
      {:ok, %Req.Response{status: s}} when s in [401, 403] -> {:error, :unauthorized}
      {:ok, %Req.Response{body: %{"detail" => detail}}} -> {:error, detail}
      {:ok, %Req.Response{status: s}} -> {:error, {:http, s}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp post(path, body) do
    case Req.post(root_url() <> path, [json: body, retry: false] ++ req_options()) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Req.Response{body: %{"detail" => detail}}} -> {:error, detail}
      {:ok, %Req.Response{status: s}} -> {:error, {:http, s}}
      {:error, reason} -> {:error, reason}
    end
  end

  # member/login answers [idnumber, token]; accounts login answers a bare token.
  defp extract_token(token) when is_binary(token), do: {:ok, token}

  defp extract_token(list) when is_list(list),
    do: list |> Enum.find(&is_binary/1) |> then(&if(&1, do: {:ok, &1}, else: {:error, :no_token}))

  defp extract_token(%{"token" => t}), do: {:ok, t}
  defp extract_token(%{"access_token" => t}), do: {:ok, t}
  defp extract_token(_), do: {:error, :no_token}

  defp root_url,
    do: base_url() |> URI.parse() |> Map.merge(%{path: nil, query: nil}) |> URI.to_string()

  @doc "All series of a past season with only `round` in them (season like \"2526\")."
  def archive_results(season, round), do: get("/icresultsarchive?season=#{season}&round=#{round}")

  @doc "Official standings of a past season."
  def archive_standings(season), do: get("/icstandingsarchive?season=#{season}")

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
