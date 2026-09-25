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

  test "keeps encounters the API did return and skips byes" do
    assert Schedule.complete(@series) == @series

    small = %{
      "teams" => for(n <- 1..10, do: %{"pairingnumber" => n, "idclub" => n}),
      "rounds" => [%{"round" => 1, "encounters" => []}]
    }

    # 1-12 and 2-11 are byes in a 10-team series
    assert length(hd(Schedule.complete(small)["rounds"])["encounters"]) == 4
  end
end
