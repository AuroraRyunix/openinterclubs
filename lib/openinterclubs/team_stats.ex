defmodule OpenInterclubs.TeamStats do
  @moduledoc "Per-board and per-player statistics of a team over its played games."

  alias OpenInterclubs.Season
  alias OpenInterclubs.Season.Result

  @doc """
  Every player who played for the team (by lineup), sorted by rating, with
  the boards they played, their games and score for this team.
  """
  def lineup(key) do
    for(
      e <- Season.team_encounters(key),
      g <- e.games,
      side <- [:home, :visit],
      Map.fetch!(e, side) == key,
      id = Map.get(g, side),
      id,
      do: {id, g.board}
    )
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {id, boards} ->
      p = Season.player(id)
      own = if p, do: Enum.filter(p.games, &(&1.team == key and &1.score != nil)), else: []

      %{
        id: id,
        player: p,
        boards: Enum.frequencies(boards),
        games: length(own),
        score: own |> Enum.map(& &1.score) |> Enum.sum()
      }
    end)
    |> Enum.sort_by(&(-((&1.player && &1.player.rating) || 0)))
  end

  @doc "Returns %{boards: [...], players: [...]} for a team key."
  def for_team(key) do
    games =
      for e <- Season.team_encounters(key),
          side = if(e.home == key, do: :home, else: :visit),
          other = if(side == :home, do: :visit, else: :home),
          g <- e.games,
          g.result != nil do
        %{
          board: g.board,
          player: Map.get(g, side),
          opponent: Map.get(g, other),
          color: if(g.white == side, do: :white, else: :black),
          score: Result.score(g.result, side),
          forfeit: Result.forfeit?(g.result)
        }
      end

    %{boards: boards(games), players: players(games)}
  end

  defp boards(games) do
    games
    |> Enum.group_by(& &1.board)
    |> Enum.sort()
    |> Enum.map(fn {board, gs} ->
      %{
        board: board,
        games: length(gs),
        score: gs |> Enum.map(& &1.score) |> Enum.sum(),
        own_rating: avg(for g <- gs, not g.forfeit, do: rating(g.player)),
        opp_rating: avg(for g <- gs, not g.forfeit, do: rating(g.opponent))
      }
    end)
  end

  defp players(games) do
    games
    |> Enum.filter(& &1.player)
    |> Enum.group_by(& &1.player)
    |> Enum.map(fn {id, gs} ->
      %{
        id: id,
        games: length(gs),
        white: Enum.count(gs, &(&1.color == :white)),
        black: Enum.count(gs, &(&1.color == :black)),
        score: gs |> Enum.map(& &1.score) |> Enum.sum(),
        avg_board: Float.round(Enum.sum(Enum.map(gs, & &1.board)) / length(gs), 1)
      }
    end)
    |> Enum.sort_by(&{-&1.games, &1.avg_board})
  end

  defp rating(nil), do: nil

  defp rating(id) do
    case Season.player(id) do
      %{rating: r} when r > 0 -> r
      _ -> nil
    end
  end

  defp avg(list) do
    case Enum.reject(list, &is_nil/1) do
      [] -> nil
      l -> round(Enum.sum(l) / length(l))
    end
  end
end
