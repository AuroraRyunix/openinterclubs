defmodule OpenInterclubs.HeadToHead do
  @moduledoc "All encounters between the teams of two clubs, over every loaded season."

  alias OpenInterclubs.Season
  alias OpenInterclubs.Season.Archive

  @doc """
  Returns `[%{season: nil | "2526", encounters: [...]}]`, newest first.
  Each encounter is annotated with the team names and `a_bp`/`b_bp` board
  points from club `a`'s point of view.
  """
  def between(a, b) do
    previous = Season.selected()

    try do
      for season <- [nil | Archive.seasons()] do
        Season.use_season(season)
        %{season: season, encounters: encounters(a, b)}
      end
      |> Enum.reject(&(&1.encounters == []))
    after
      Season.use_season(previous)
    end
  end

  defp encounters(a, b) do
    teams = Season.teams()

    for s <- Map.values(Season.series()),
        r <- s.rounds,
        e <- r.encounters,
        home = teams[e.home],
        visit = teams[e.visit],
        MapSet.new([home.club_id, visit.club_id]) == MapSet.new([a, b]) do
      a_home? = home.club_id == a

      Map.merge(e, %{
        home_name: home.name,
        visit_name: visit.name,
        a_bp: if(a_home?, do: e.bp_home, else: e.bp_visit),
        b_bp: if(a_home?, do: e.bp_visit, else: e.bp_home),
        a_mp: if(a_home?, do: e.mp_home, else: e.mp_visit)
      })
    end
    |> Enum.sort_by(&{&1.round, &1.series})
  end

  @doc "Totals from club a's point of view: won/drawn/lost matches, board points."
  def totals(seasons) do
    played = for %{encounters: es} <- seasons, e <- es, e.status != :planned, do: e

    %{
      won: Enum.count(played, &(&1.a_mp == 2)),
      drawn: Enum.count(played, &(&1.a_mp == 1)),
      lost: Enum.count(played, &(&1.a_mp == 0)),
      a_bp: played |> Enum.map(&(&1.a_bp || 0.0)) |> Enum.sum(),
      b_bp: played |> Enum.map(&(&1.b_bp || 0.0)) |> Enum.sum()
    }
  end
end
