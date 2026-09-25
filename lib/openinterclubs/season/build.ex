defmodule OpenInterclubs.Season.Build do
  @moduledoc """
  Turns raw KBSB API responses into the season model: clubs, teams, series
  with standings, encounters and players with their games, score and TPR.
  Pure, so it can be tested with fixtures.
  """

  alias OpenInterclubs.Season.{Result, Tpr}

  @boards %{1 => 8, 2 => 8, 3 => 6, 4 => 4, 5 => 4, 6 => 4}

  @provinces %{
    1 => "Antwerpen",
    2 => "Brussel & Vlaams-Brabant",
    3 => "West-Vlaanderen",
    4 => "Oost-Vlaanderen",
    5 => "Henegouwen",
    6 => "Luik",
    7 => "Limburg",
    8 => "Luxemburg",
    9 => "Namen & Waals-Brabant"
  }

  def boards(division), do: Map.get(@boards, division, 4)
  def provinces, do: @provinces
  def province(idclub), do: Map.get(@provinces, div(idclub, 100), "Andere")

  def series_label(1, _), do: "1"
  def series_label(div, idx), do: "#{div}#{idx}"

  @doc """
  `clubs` is the `/icclub` list, `details` a map idclub => `/icclub/{id}`,
  `series` a list of `/icresults/{div}/{idx}` responses.
  """
  def build(clubs, details, series) do
    teams = build_teams(clubs)
    team_by_pnr = Map.new(teams, fn {_k, t} -> {{t.division, t.index, t.pairingnr}, t.key} end)
    players = build_players(details)

    series = Enum.map(series, &build_series(&1, team_by_pnr))
    encounters = Enum.flat_map(series, fn s -> Enum.flat_map(s.rounds, & &1.encounters) end)
    players = attach_games(players, encounters, teams)

    clubs =
      clubs
      |> Enum.filter(&(&1["teams"] != []))
      |> Map.new(fn c ->
        id = c["idclub"]

        {id,
         %{
           id: id,
           name: c["name"],
           province: province(id),
           teams: c["teams"] |> Enum.map(&team_key/1) |> Enum.sort_by(&teams[&1].number),
           players:
             players
             |> Map.values()
             |> Enum.filter(&(&1.club_id == id))
             |> Enum.sort_by(&(-&1.rating))
             |> Enum.map(& &1.id)
         }}
      end)

    %{
      clubs: clubs,
      teams: teams,
      series: Map.new(series, &{&1.key, &1}),
      players: players,
      rounds: rounds_overview(series)
    }
  end

  # ---- teams -------------------------------------------------------------

  defp team_key(t), do: {t["idclub"], team_number(t["name"])}

  defp team_number(name) do
    case Regex.run(~r/(\d+)\s*$/, name || "") do
      [_, n] -> String.to_integer(n)
      _ -> 1
    end
  end

  defp build_teams(clubs) do
    for c <- clubs, t <- c["teams"], into: %{} do
      key = team_key(t)

      {key,
       %{
         key: key,
         club_id: t["idclub"],
         club_name: c["name"],
         number: elem(key, 1),
         name: t["name"],
         division: t["division"],
         index: t["index"] || "",
         series: {t["division"], t["index"] || ""},
         pairingnr: t["pairingnumber"],
         forfeit: t["teamforfeit"] == true
       }}
    end
  end

  # ---- players -----------------------------------------------------------

  defp build_players(details) do
    for {idclub, d} <- details,
        p <- d["players"] || [],
        p["idnumber"] not in [nil, 0],
        into: %{} do
      {p["idnumber"],
       %{
         id: p["idnumber"],
         first_name: p["first_name"],
         last_name: p["last_name"],
         name: "#{p["first_name"]} #{p["last_name"]}",
         club_id: idclub,
         rating: p["assignedrating"] || 0,
         fide: p["fiderating"] || 0,
         nat: p["natrating"] || 0,
         titular: blank_nil(p["titular"]),
         games: [],
         score: 0.0,
         played: 0,
         tpr: nil,
         diff: nil
       }}
    end
  end

  defp blank_nil(""), do: nil
  defp blank_nil(v), do: v

  # ---- series & encounters -----------------------------------------------

  defp build_series(s, team_by_pnr) do
    div = s["division"]
    idx = s["index"] || ""
    key = {div, idx}
    resolve = &Map.get(team_by_pnr, {div, idx, &1})

    rounds =
      Enum.map(s["rounds"] || [], fn r ->
        %{
          round: r["round"],
          date: parse_date(r["rdate"]),
          encounters:
            r["encounters"]
            |> Enum.map(&build_encounter(&1, key, r["round"], parse_date(r["rdate"]), resolve))
            |> Enum.reject(&(is_nil(&1.home) or is_nil(&1.visit)))
        }
      end)

    teams = s["teams"] |> Enum.map(&resolve.(&1["pairingnumber"])) |> Enum.reject(&is_nil/1)

    %{
      key: key,
      division: div,
      index: idx,
      label: series_label(div, idx),
      teams: teams,
      rounds: rounds,
      standings: standings(teams, rounds)
    }
  end

  defp build_encounter(e, series, round, date, resolve) do
    games =
      (e["games"] || [])
      |> Enum.with_index(1)
      |> Enum.map(fn {g, board} ->
        %{
          board: board,
          home: nonzero(g["idnumber_home"]),
          visit: nonzero(g["idnumber_visit"]),
          result: Result.parse(g),
          # KBSB: the home team has white on the odd boards.
          white: if(rem(board, 2) == 1, do: :home, else: :visit)
        }
      end)

    {bp_home, bp_visit, mp_home, mp_visit, status} = score_encounter(e, games)

    %{
      series: series,
      round: round,
      date: date,
      home: resolve.(e["pairingnr_home"]),
      visit: resolve.(e["pairingnr_visit"]),
      games: games,
      bp_home: bp_home,
      bp_visit: bp_visit,
      mp_home: mp_home,
      mp_visit: mp_visit,
      status: status
    }
  end

  # Official score once the API marks it played; otherwise a live score from
  # the games entered so far.
  defp score_encounter(e, games) do
    results = Enum.map(games, & &1.result)

    cond do
      e["played"] == true ->
        {(e["boardpoint2_home"] || 0) / 2, (e["boardpoint2_visit"] || 0) / 2,
         e["matchpoint_home"] || 0, e["matchpoint_visit"] || 0, :final}

      Enum.any?(results) ->
        h = results |> Enum.map(&(Result.score(&1, :home) || 0.0)) |> Enum.sum()
        v = results |> Enum.map(&(Result.score(&1, :visit) || 0.0)) |> Enum.sum()
        {mh, mv} = match_points(h, v)
        status = if Enum.all?(results), do: :final, else: :live
        {h, v, mh, mv, status}

      true ->
        {nil, nil, nil, nil, :planned}
    end
  end

  defp match_points(h, v) when h > v, do: {2, 0}
  defp match_points(h, v) when h < v, do: {0, 2}
  defp match_points(_, _), do: {1, 1}

  defp nonzero(id) when id in [nil, 0], do: nil
  defp nonzero(id), do: id

  defp parse_date(nil), do: nil

  defp parse_date(s) do
    case Date.from_iso8601(s) do
      {:ok, d} -> d
      _ -> nil
    end
  end

  # ---- standings ---------------------------------------------------------

  @doc false
  def standings(teams, rounds) do
    empty = %{played: 0, won: 0, drawn: 0, lost: 0, mp: 0, bp: 0.0, bp_against: 0.0}
    acc = Map.new(teams, &{&1, empty})

    acc =
      for r <- rounds, e <- r.encounters, e.status != :planned, reduce: acc do
        acc ->
          acc
          |> Map.update(e.home, empty, &add(&1, e.mp_home, e.bp_home, e.bp_visit))
          |> Map.update(e.visit, empty, &add(&1, e.mp_visit, e.bp_visit, e.bp_home))
      end

    acc
    |> Enum.map(fn {team, row} -> Map.put(row, :team, team) end)
    |> Enum.sort_by(&{-&1.mp, -&1.bp})
    |> Enum.with_index(1)
    |> Enum.map(fn {row, rank} -> Map.put(row, :rank, rank) end)
  end

  defp add(row, mp, bp, bp_against) do
    %{
      row
      | played: row.played + 1,
        won: row.won + if(mp == 2, do: 1, else: 0),
        drawn: row.drawn + if(mp == 1, do: 1, else: 0),
        lost: row.lost + if(mp == 0, do: 1, else: 0),
        mp: row.mp + mp,
        bp: row.bp + bp,
        bp_against: row.bp_against + bp_against
    }
  end

  # ---- player games & stats ----------------------------------------------

  defp attach_games(players, encounters, teams) do
    games =
      for e <- encounters,
          g <- e.games,
          side <- [:home, :visit],
          id = Map.get(g, side),
          id != nil do
        other = if side == :home, do: :visit, else: :home
        opp = Map.get(g, other)

        {id,
         %{
           series: e.series,
           round: e.round,
           date: e.date,
           board: g.board,
           color: if(g.white == side, do: :white, else: :black),
           side: side,
           team: Map.fetch!(e, side),
           opp_team: Map.fetch!(e, other),
           opponent: opp,
           opponent_rating: opp && get_in(players, [opp, :rating]),
           result: g.result,
           score: Result.score(g.result, side),
           label: Result.label(g.result, side)
         }}
      end

    by_player = Enum.group_by(games, &elem(&1, 0), &elem(&1, 1))

    Map.new(players, fn {id, p} ->
      games = by_player |> Map.get(id, []) |> Enum.sort_by(& &1.round)
      {id, stats(p, games, teams)}
    end)
  end

  defp stats(p, games, _teams) do
    scored = Enum.filter(games, &(&1.score != nil))
    rated = Enum.reject(scored, &(Result.forfeit?(&1.result) or is_nil(&1.opponent_rating)))
    score = rated |> Enum.map(& &1.score) |> Enum.sum()
    tpr = Tpr.tpr(Enum.map(rated, & &1.opponent_rating), score)

    %{
      p
      | games: games,
        score: scored |> Enum.map(& &1.score) |> Enum.sum(),
        played: length(scored),
        tpr: tpr,
        diff: tpr && tpr - p.rating
    }
    |> Map.put(:rated_games, length(rated))
  end

  # ---- round overview ----------------------------------------------------

  defp rounds_overview(series) do
    series
    |> Enum.flat_map(fn s -> Enum.map(s.rounds, &{&1.round, &1.date}) end)
    |> Enum.uniq_by(&elem(&1, 0))
    |> Enum.sort()
    |> Enum.map(fn {round, date} -> %{round: round, date: date} end)
  end
end
