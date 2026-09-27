defmodule OpenInterclubs.TeamStats do
  @moduledoc "Per-board and per-player statistics of a team over its played games."

  alias OpenInterclubs.Season
  alias OpenInterclubs.Season.Result

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
