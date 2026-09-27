defmodule OpenInterclubs.ScheduleTest do
  use ExUnit.Case, async: true

  alias OpenInterclubs.Schedule

  @series "test/fixtures/series_2A.json" |> File.read!() |> Jason.decode!()

  test "rebuilt pairings match the real round 1 of series 2A" do
    real =
      for e <- hd(@series["rounds"])["encounters"],
          do: {e["pairingnr_home"], e["pairingnr_visit"]}

    emptied =
      update_in(@series, ["rounds"], fn rs -> Enum.map(rs, &Map.put(&1, "encounters", [])) end)

    rebuilt =
      for e <- hd(Schedule.complete(emptied)["rounds"])["encounters"],
          do: {e["pairingnr_home"], e["pairingnr_visit"]}

    assert Enum.sort(rebuilt) == Enum.sort(real)
  end

  test "keeps encounters the API did return; 10-team series use their own table" do
    assert Schedule.complete(@series) == @series

    small = %{
      "teams" => for(n <- 1..10, do: %{"pairingnumber" => n, "idclub" => n}),
      "rounds" => [%{"round" => 1, "encounters" => []}]
    }

    # division 6: 10 teams use the KBSB 10-team table (5 matches a round)
    assert [{1, 10}, {2, 9}, {3, 8}, {4, 7}, {5, 6}] =
             for(
               e <- hd(Schedule.complete(small)["rounds"])["encounters"],
               do: {e["pairingnr_home"], e["pairingnr_visit"]}
             )
  end
end
