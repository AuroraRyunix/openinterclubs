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
  Log in with a KBSB member login (step 1).

  * `{:ok, token, idnumber}`: logged in (`idnumber` may be nil);
  * `{:two_factor, challenge}`: the account has 2FA; ask for the code and
    call `login_2fa/2` with the challenge;
  * `{:error, reason}`.

  Nothing is stored here; the password is only passed on to the KBSB.
  """
  def login(user, password) do
    user = String.trim(user)

    with {:ok, body} <- post("/api/v1/member/login", %{email: user, password: password}) do
      login_reply(body, user)
    end
  end

  @doc """
  Step 2 for accounts with 2FA: the one-time code plus what step 1 returned
  (`csrf`, `session_id` and the signed `state`).
  """
  def login_2fa(%{csrf: csrf, session_id: sid, state: state, user: user}, code) do
    body = %{
      csrf: csrf,
      code2FA: code |> to_string() |> String.replace(~r/\s+/, ""),
      session_id: sid,
      state: state,
      # the KBSB takes the identity from `state`; the field is only kept for
      # backends that still read it
      email: user
    }

    with {:ok, reply} <- post("/api/v1/member/login2fa", body) do
      case login_reply(reply, user) do
        {:two_factor, _} -> {:error, :two_factor_again}
        other -> other
      end
    end
  end

  # LoginReply: %{"id", "jwttoken", "csrf", "session_id", "state", "is2FAneeded"};
  # older backends answered [idnumber, token] or a bare token.
  defp login_reply(%{"is2FAneeded" => true} = m, user) do
    {:two_factor,
     %{
       csrf: m["csrf"] || "",
       session_id: m["session_id"] || "",
       state: m["state"] || "",
       user: user
     }}
  end

  defp login_reply(%{"jwttoken" => t} = m, user) when is_binary(t) and t != "" do
    {:ok, t, member_number(m["id"], t, user)}
  end

  defp login_reply(body, user) do
    with {:ok, token} <- extract_token(body) do
      id = if is_list(body), do: Enum.find(body, &is_integer/1)
      {:ok, token, member_number(id, token, user)}
    end
  end

  # The member number: the reply's id, else the token's `sub`, else the
  # login if it is a number.
  defp member_number(id, _token, _user) when is_integer(id) and id > 0, do: id

  defp member_number(_id, token, user) do
    with [_, payload, _] <- String.split(token, "."),
         {:ok, json} <- Base.url_decode64(payload, padding: false),
         {:ok, %{"sub" => sub}} <- Jason.decode(json),
         {n, ""} <- Integer.parse(to_string(sub)) do
      n
    else
      _ ->
        case Integer.parse(user) do
          {n, ""} -> n
          _ -> nil
        end
    end
  end

  @doc "A member's display name (public member record), e.g. \"Jorian Burssens\"."
  def member_name(idnumber) when is_integer(idnumber) do
    case Req.get(
           root_url() <> "/api/v1/member/anon/member/#{idnumber}",
           [retry: false] ++ req_options()
         ) do
      {:ok, %Req.Response{status: 200, body: %{"first_name" => f, "last_name" => l}}} ->
        {:ok, String.trim("#{f} #{l}")}

      _ ->
        :error
    end
  end

  def member_name(_), do: :error

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
