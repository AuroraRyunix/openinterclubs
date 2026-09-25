defmodule OpenInterclubs.Fiche do
  @moduledoc """
  Builds the data for one "uitslagenfiche / feuille de résultats" of an
  interclub encounter, from the raw KBSB API structures.
  """

  alias OpenInterclubs.Kbsb

  # Boards per division when the API has no lineup yet.
  @boards %{1 => 8, 2 => 8, 3 => 6, 4 => 4, 5 => 4, 6 => 4}

  # `boards` is what's on the sheet; it starts blank. `api_boards` holds the
  # lineup published on the KBSB site, copied in on request (`fill/2`).
  defstruct [:division, :index, :round, :date, :home, :visit, boards: [], api_boards: []]

  @doc "Fetch everything needed and build the fiche for `team` of a club in `round`."
  def fetch(team, round, opts \\ []) do
    if opts[:fresh] do
      Kbsb.Cache.delete_matching(fn key ->
        String.starts_with?(key, ["/icresults", "/icclub/"])
      end)
    end

    with {:ok, series} <- Kbsb.series(team["division"], team["index"]),
         {:ok, encounter} <- find_encounter(series, team["pairingnumber"], round),
         {:ok, home_club} <- Kbsb.club(encounter["icclub_home"]),
         {:ok, visit_club} <- Kbsb.club(encounter["icclub_visit"]) do
      fiche = build(series, round, encounter, home_club["players"], visit_club["players"])

      {:ok,
       %{
         fiche
         | home: Map.put(fiche.home, :options, player_options(home_club["players"])),
           visit: Map.put(fiche.visit, :options, player_options(visit_club["players"]))
       }}
    end
  end

  @doc "The encounter a team (by pairing number) plays in a given round."
  def find_encounter(series, pairingnr, round) do
    with %{} = rnd <- Enum.find(series["rounds"], &(&1["round"] == round)),
         %{} = enc <-
           Enum.find(rnd["encounters"], fn e ->
             pairingnr in [e["pairingnr_home"], e["pairingnr_visit"]]
           end) do
      {:ok, Map.put(enc, "rdate", rnd["rdate"])}
    else
      _ -> {:error, :no_encounter}
    end
  end

  @doc "Pure builder, see `fetch/2`."
  def build(series, round, encounter, home_players, visit_players) do
    teams = Map.new(series["teams"], &{&1["pairingnumber"], &1})
    home_by_id = Map.new(home_players || [], &{&1["idnumber"], &1})
    visit_by_id = Map.new(visit_players || [], &{&1["idnumber"], &1})

    games =
      case encounter["games"] do
        [_ | _] = games -> games
        _ -> List.duplicate(%{}, Map.get(@boards, series["division"], 8))
      end

    api_boards =
      games
      |> Enum.with_index(1)
      |> Enum.map(fn {g, n} ->
        %{
          board: n,
          home: player(home_by_id, g["idnumber_home"]),
          visit: player(visit_by_id, g["idnumber_visit"])
        }
      end)

    home = side(teams, encounter["pairingnr_home"], encounter["icclub_home"])
    visit = side(teams, encounter["pairingnr_visit"], encounter["icclub_visit"])

    %__MODULE__{
      division: series["division"],
      index: series["index"],
      round: round,
      date: encounter["rdate"],
      home: home,
      visit: visit,
      api_boards: api_boards,
      boards: Enum.map(api_boards, &%{&1 | home: nil, visit: nil})
    }
  end

  defp name(p), do: "#{p["last_name"]} #{p["first_name"]}"

  defp side(teams, pairingnr, idclub) do
    team = Map.get(teams, pairingnr, %{})
    %{name: team["name"] || "?", idclub: idclub, pairingnr: pairingnr, options: []}
  end

  defp player(_by_id, id) when id in [nil, 0], do: nil

  defp player(by_id, id) do
    case Map.get(by_id, id) do
      nil -> %{idnumber: id, name: nil, rating: nil}
      p -> %{idnumber: id, name: name(p), rating: p["assignedrating"]}
    end
  end

  @doc "Copy the KBSB lineup onto the sheet for :home, :visit or :all."
  def fill(%__MODULE__{} = fiche, :all), do: fiche |> fill(:home) |> fill(:visit)

  def fill(%__MODULE__{} = fiche, side) when side in [:home, :visit] do
    api = Map.new(fiche.api_boards, &{&1.board, Map.get(&1, side)})
    %{fiche | boards: Enum.map(fiche.boards, &Map.put(&1, side, api[&1.board]))}
  end

  @doc "Remove all players of :home, :visit or :all from the sheet."
  def clear(%__MODULE__{} = fiche, :all), do: fiche |> clear(:home) |> clear(:visit)

  def clear(%__MODULE__{} = fiche, side) when side in [:home, :visit],
    do: %{fiche | boards: Enum.map(fiche.boards, &Map.put(&1, side, nil))}

  @doc "Keep what's on the sheet but take a newer KBSB lineup."
  def refresh_api(%__MODULE__{} = fiche, %__MODULE__{} = fresh),
    do: %{fiche | api_boards: fresh.api_boards}

  @doc """
  Take lineups from the authenticated club endpoint (`Kbsb.club_series/3`
  output) into `api_boards`, for whichever side the logged-in club is.
  """
  def merge_club_series(%__MODULE__{} = fiche, series_list) do
    enc =
      Enum.find_value(series_list, fn s ->
        (s["division"] == fiche.division and (s["index"] || "") == (fiche.index || "")) &&
          Enum.find_value(s["rounds"] || [], fn r ->
            r["round"] == fiche.round &&
              Enum.find(r["encounters"] || [], fn e ->
                e["pairingnr_home"] == fiche.home.pairingnr and
                  e["pairingnr_visit"] == fiche.visit.pairingnr
              end)
          end)
      end)

    case enc do
      %{"games" => [_ | _] = games} ->
        api =
          fiche.api_boards
          |> Enum.with_index()
          |> Enum.map(fn {b, i} ->
            g = Enum.at(games, i, %{})

            %{
              b
              | home: b.home || from_options(fiche.home.options, g["idnumber_home"]),
                visit: b.visit || from_options(fiche.visit.options, g["idnumber_visit"])
            }
          end)

        %{fiche | api_boards: api}

      _ ->
        fiche
    end
  end

  defp from_options(_options, id) when id in [nil, 0], do: nil

  # Option labels look like "Last First (1234)"; split off the rating.
  defp from_options(options, id) do
    label = Enum.find_value(options, fn {label, oid} -> oid == id && label end)

    case label && Regex.run(~r/^(.*) \((\d+)\)$/, label) do
      [_, name, rating] -> %{idnumber: id, name: name, rating: String.to_integer(rating)}
      _ -> %{idnumber: id, name: label, rating: nil}
    end
  end

  @doc "Whether the KBSB site has any lineup for that side."
  def api_lineup?(%__MODULE__{} = fiche, side),
    do: Enum.any?(fiche.api_boards, &Map.get(&1, side))

  @doc "Put a player (by idnumber, or nil to clear) on a board for :home or :visit."
  def set_player(%__MODULE__{} = fiche, board, side, idnumber) when side in [:home, :visit] do
    value = if idnumber, do: from_options(Map.fetch!(fiche, side).options, idnumber)

    boards =
      Enum.map(fiche.boards, fn
        %{board: ^board} = b -> Map.put(b, side, value)
        b -> b
      end)

    %{fiche | boards: boards}
  end

  @doc "Selectable players of a club, for filling a board by hand."
  def player_options(players) do
    (players || [])
    |> Enum.sort_by(&(-(&1["assignedrating"] || 0)))
    |> Enum.map(
      &{"#{&1["last_name"]} #{&1["first_name"]} (#{&1["assignedrating"]})", &1["idnumber"]}
    )
  end
end
