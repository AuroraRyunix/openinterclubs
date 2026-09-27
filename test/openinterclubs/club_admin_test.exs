defmodule OpenInterclubs.ClubAdminTest do
  use ExUnit.Case, async: true

  alias OpenInterclubs.ClubAdmin

  @series "test/fixtures/series_2A.json" |> File.read!() |> Jason.decode!()

  # Club endpoint answer for 472 in round 1: 472 at home vs 402.
  defp club_series, do: [put_in(@series, ["rounds"], [hd(@series["rounds"])])]

  test "lists the club's own team with its lineup and opponent" do
    [t] = ClubAdmin.teams(club_series(), 472, 1)

    assert %{name: "de Mercatel 1", playinghome: true, pairingnumber: 2, nrgames: 8} = t
    assert %{idclub: 402, name: "Jean Jaures Gent 1", pairingnumber: 11} = t.opponent
    assert hd(t.lineup) == 14108
    assert Enum.all?(t.opponent_lineup, &is_nil/1)
    assert ClubAdmin.filled(t) == 8
  end

  test "planning payload puts players in the own side's field" do
    teams = ClubAdmin.teams(club_series(), 472, 1) |> ClubAdmin.set_player("2A-2", 8, nil)
    p = ClubAdmin.planning(472, 1, teams)

    assert %{idclub: 472, round: 1, plannings: [plan]} = p
    assert %{playinghome: true, pairingnumber: 2, idclub_opponent: 402, nrgames: 8} = plan
    assert hd(plan.games) == %{idnumber_home: 14108}
    assert List.last(plan.games) == %{idnumber_home: 0}

    # As the away club the visit field is used.
    [away] = ClubAdmin.teams(club_series(), 402, 1)
    assert %{playinghome: false} = away

    assert [%{plannings: [%{games: [%{idnumber_visit: 0} | _]}]}] = [
             ClubAdmin.planning(402, 1, [away])
           ]
  end

  test "result item orients both lineups and results home/visit" do
    [t] = ClubAdmin.teams(club_series(), 472, 1)
    t = %{t | opponent_lineup: List.duplicate(555, 8)}
    [t] = ClubAdmin.set_result([t], "2A-2", 1, "1-0")

    item = ClubAdmin.result_item(t)
    assert %{icclub_home: 472, icclub_visit: 402, pairingnr_home: 2, pairingnr_visit: 11} = item
    assert hd(item.games) == %{idnumber_home: 14108, idnumber_visit: 555, result: "1-0"}
  end

  test "rejects unknown result codes" do
    [t] = ClubAdmin.teams(club_series(), 472, 1)
    assert_raise FunctionClauseError, fn -> ClubAdmin.set_result([t], "2A-2", 1, "2-0") end
  end

  test "round opens at 14:00 Belgian time, summer and winter" do
    # summer time (CEST): 14:00 = 12:00 UTC
    refute ClubAdmin.round_open?("2026-09-27", ~U[2026-09-27 11:59:00Z])
    assert ClubAdmin.round_open?("2026-09-27", ~U[2026-09-27 12:00:00Z])
    # winter time (CET): 14:00 = 13:00 UTC
    refute ClubAdmin.round_open?("2026-11-15", ~U[2026-11-15 12:30:00Z])
    assert ClubAdmin.round_open?("2026-11-15", ~U[2026-11-15 13:00:00Z])
    # the day after is always open
    assert ClubAdmin.round_open?("2026-11-15", ~U[2026-11-16 09:00:00Z])
    # last Sunday of October 2026 is the 25th: already winter time
    refute ClubAdmin.round_open?("2026-10-25", ~U[2026-10-25 12:30:00Z])
    # last Sunday of March 2027 is the 28th: already summer time
    assert ClubAdmin.round_open?("2027-03-28", ~U[2027-03-28 12:00:00Z])
  end
end
