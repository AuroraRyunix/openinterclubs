defmodule OpenInterclubs.Season.BuildTest do
  use ExUnit.Case, async: true

  alias OpenInterclubs.Season.{Result, Tpr}

  import OpenInterclubs.SeasonFixtures

  setup do
    %{model: model()}
  end

  test "scores encounters and marks unfinished ones live", %{model: m} do
    [r1, r2] = m.series[{4, "B"}].rounds
    [e1] = r1.encounters
    assert %{bp_home: 2.5, bp_visit: 1.5, mp_home: 2, mp_visit: 0, status: :final} = e1
    assert Enum.map(e1.games, & &1.white) == [:home, :visit, :home, :visit]

    [e2] = r2.encounters
    assert %{bp_home: +0.0, bp_visit: 1.0, status: :live} = e2
  end

  test "standings order by match points then board points", %{model: m} do
    [first, second, third] = m.series[{4, "B"}].standings
    assert %{team: {401, 1}, mp: 4, bp: 3.5, played: 2, won: 2} = first
    assert %{team: {472, 2}, mp: 0, bp: 1.5} = second
    assert %{team: {109, 3}, mp: 0, bp: +0.0} = third
  end

  test "player stats: score, colours, TPR without forfeits", %{model: m} do
    p1 = m.players[1]
    assert p1.played == 2 and p1.score == 2.0
    assert [%{color: :white, label: "1"}, %{color: :black, label: "1", opponent: 21}] = p1.games
    # 2/2 against 1800 and 1500 → avg 1650 + 800
    assert p1.tpr == 2450

    p4 = m.players[4]
    assert p4.played == 1 and p4.score == 1.0 and p4.rated_games == 0 and p4.tpr == nil
    assert [%{label: "1F"}, %{label: "", score: nil}] = p4.games
  end

  test "clubs carry province and teams" do
    m = model()
    assert %{province: "Oost-Vlaanderen", teams: [{401, 1}], players: [1, 2, 3, 4]} = m.clubs[401]
    assert m.teams[{472, 2}].number == 2
  end

  test "result parsing honours overruled and labels" do
    assert Result.parse(%{"result" => "1-0", "overruled" => "0-1 FF"}) == :visit_ff
    assert Result.parse(%{"result" => "½-½", "overruled" => "NOR"}) == :draw
    assert Result.parse(%{"result" => ""}) == nil
    assert Result.display(:home_ff) == "1F-0F"
  end

  test "tpr dp table is symmetric" do
    assert Tpr.dp(50) == 0
    assert Tpr.dp(100) == 800
    assert Tpr.dp(75) == -Tpr.dp(25)
  end
end
