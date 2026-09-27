defmodule OpenInterclubs.ClubAdmin do
  @moduledoc """
  Data for the IC admin page: the club's teams in one round, their lineups
  and results as the KBSB club endpoint returns them, and the payloads to
  validate/save a planning (`clb/icplanning`) and results (`clb/icresults`),
  mirroring the KBSB backend (`_apply_planning`, `clb_saveICresults`).
  """

  alias OpenInterclubs.Season.Build

  @results ["", "1-0", "½-½", "0-1", "1-0 FF", "0-1 FF", "0-0 FF", "½-0", "0-½"]
  def result_options, do: @results

  @doc "The club's teams playing `round`, from `Kbsb.club_series/3` output."
  def teams(series_list, idclub, round) do
    for s <- series_list,
        r <- s["rounds"] || [],
        r["round"] == round,
        e <- r["encounters"] || [],
        idclub in [e["icclub_home"], e["icclub_visit"]] do
      names = Map.new(s["teams"] || [], &{&1["pairingnumber"], &1["name"]})
      home? = e["icclub_home"] == idclub
      nrgames = Build.boards(s["division"])
      games = pad(e["games"] || [], nrgames)

      {own, opp} =
        if home?,
          do: {"idnumber_home", "idnumber_visit"},
          else: {"idnumber_visit", "idnumber_home"}

      pnr = if home?, do: e["pairingnr_home"], else: e["pairingnr_visit"]
      opp_pnr = if home?, do: e["pairingnr_visit"], else: e["pairingnr_home"]

      %{
        key: "#{s["division"]}#{s["index"]}-#{pnr}",
        division: s["division"],
        index: s["index"] || "",
        round: round,
        date: r["rdate"],
        name: names[pnr],
        pairingnumber: pnr,
        playinghome: home?,
        opponent: %{
          idclub: if(home?, do: e["icclub_visit"], else: e["icclub_home"]),
          name: names[opp_pnr],
          pairingnumber: opp_pnr
        },
        encounter:
          Map.take(e, ["icclub_home", "icclub_visit", "pairingnr_home", "pairingnr_visit"]),
        nrgames: nrgames,
        lineup: Enum.map(games, &nonzero(&1[own])),
        opponent_lineup: Enum.map(games, &nonzero(&1[opp])),
        results: Enum.map(games, &(&1["result"] || "")),
        played: e["played"] == true
      }
    end
    |> Enum.sort_by(&{&1.division, &1.index, &1.name})
  end

  defp pad(games, n), do: games ++ List.duplicate(%{}, max(n - length(games), 0))

  defp nonzero(id) when id in [nil, 0], do: nil
  defp nonzero(id), do: id

  def set_player(teams, key, board, id), do: update(teams, key, :lineup, board, id)

  def set_result(teams, key, board, res) when res in @results,
    do: update(teams, key, :results, board, res)

  defp update(teams, key, field, board, value) do
    Enum.map(teams, fn
      %{key: ^key} = t -> Map.update!(t, field, &List.replace_at(&1, board - 1, value))
      t -> t
    end)
  end

  @doc "Boards filled in the team's own lineup."
  def filled(team), do: Enum.count(team.lineup, & &1)

  @doc "Payload for `clb/icplanning(validate)`: every team of the club."
  def planning(idclub, round, teams) do
    %{
      idclub: idclub,
      round: round,
      plannings:
        Enum.map(teams, fn t ->
          field = if t.playinghome, do: :idnumber_home, else: :idnumber_visit

          %{
            division: t.division,
            index: t.index,
            name: t.name,
            name_opponent: t.opponent.name,
            idclub_opponent: t.opponent.idclub,
            pairingnumber: t.pairingnumber,
            playinghome: t.playinghome,
            nrgames: t.nrgames,
            games: Enum.map(t.lineup, &%{field => &1 || 0})
          }
        end)
    }
  end

  @doc "Payload item for `clb/icresults` for one team's encounter."
  def result_item(team) do
    {home, visit} =
      if team.playinghome,
        do: {team.lineup, team.opponent_lineup},
        else: {team.opponent_lineup, team.lineup}

    {name_home, name_visit} =
      if team.playinghome,
        do: {team.name, team.opponent.name},
        else: {team.opponent.name, team.name}

    Map.merge(
      %{
        division: team.division,
        index: team.index,
        round: team.round,
        name_home: name_home,
        name_visit: name_visit,
        nrgames: team.nrgames,
        games:
          [home, visit, team.results]
          |> Enum.zip()
          |> Enum.map(fn {h, v, r} ->
            %{idnumber_home: h || 0, idnumber_visit: v || 0, result: r}
          end)
      },
      %{
        icclub_home: team.encounter["icclub_home"],
        icclub_visit: team.encounter["icclub_visit"],
        pairingnr_home: team.encounter["pairingnr_home"],
        pairingnr_visit: team.encounter["pairingnr_visit"]
      }
    )
  end

  @doc """
  Whether a round is open (results can be entered, lineups are visible):
  the KBSB opens it at 14:00 Belgian time on the round date, i.e. 12:00 UTC
  in summer time (CEST) and 13:00 UTC in winter time (CET).
  """
  def round_open?(date, now \\ DateTime.utc_now())
  def round_open?(nil, _now), do: false

  def round_open?(date, now) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, d} -> round_open?(d, now)
      _ -> false
    end
  end

  def round_open?(%Date{} = d, now) do
    utc_hour = if summer_time?(d), do: 12, else: 13
    DateTime.compare(now, DateTime.new!(d, Time.new!(utc_hour, 0, 0), "Etc/UTC")) != :lt
  end

  # EU summer time: from the last Sunday of March to the last Sunday of
  # October (switch at 01:00 UTC; a 14:00 start is never near the switch).
  defp summer_time?(%Date{year: y} = d) do
    Date.compare(d, last_sunday(y, 3)) != :lt and Date.compare(d, last_sunday(y, 10)) == :lt
  end

  defp last_sunday(year, month) do
    last = Date.end_of_month(Date.new!(year, month, 1))
    Date.add(last, -rem(Date.day_of_week(last), 7))
  end
end
