defmodule OpenInterclubs.Season.Archive do
  @moduledoc """
  Loads a past season from the KBSB archive endpoints
  (`icresultsarchive?season=2526&round=N`, one call per round) into the
  same model as the current season (`OpenInterclubs.Season.Build`).

  Player names and ratings come from the current player lists; the archive
  has no historical ratings, so TPRs of past seasons are approximations.
  """

  alias OpenInterclubs.Kbsb
  alias OpenInterclubs.Season.Build

  @seasons ~w(2526 2425 2324)
  def seasons, do: @seasons

  @doc "\"2526\" -> \"2025-26\""
  def label(season), do: "20#{String.slice(season, 0, 2)}-#{String.slice(season, 2, 2)}"

  def load(season) when season in @seasons do
    rounds =
      1..11
      |> Task.async_stream(&Kbsb.archive_results(season, &1), max_concurrency: 4, timeout: 60_000)
      |> Enum.flat_map(fn
        {:ok, {:ok, list}} when is_list(list) -> list
        _ -> []
      end)

    if rounds == [] do
      {:error, :no_data}
    else
      series = merge_series(rounds)
      clubs = clubs_from(series)

      details =
        clubs
        |> Task.async_stream(fn c -> {c["idclub"], Kbsb.club(c["idclub"])} end,
          max_concurrency: 8,
          timeout: 60_000
        )
        |> Enum.flat_map(fn
          {:ok, {id, {:ok, d}}} -> [{id, d}]
          _ -> []
        end)
        |> Map.new()

      {:ok, Build.build(clubs, details, series)}
    end
  end

  def load(_), do: {:error, :unknown_season}

  # Each archive call returns every series with only that round in it.
  @doc false
  def merge_series(per_round) do
    per_round
    |> Enum.group_by(&{&1["division"], &1["index"] || ""})
    |> Enum.map(fn {{d, i}, parts} ->
      %{
        "division" => d,
        "index" => i,
        "teams" => hd(parts)["teams"],
        "rounds" => parts |> Enum.flat_map(&(&1["rounds"] || [])) |> Enum.sort_by(& &1["round"])
      }
    end)
  end

  # Club list in the /icclub shape, from the teams in the archived series.
  defp clubs_from(series) do
    current =
      case Kbsb.clubs() do
        {:ok, list} -> Map.new(list, &{&1["idclub"], &1["name"]})
        _ -> %{}
      end

    series
    |> Enum.flat_map(& &1["teams"])
    |> Enum.group_by(& &1["idclub"])
    |> Enum.map(fn {id, teams} ->
      name =
        current[id] || teams |> hd() |> Map.get("name", "") |> String.replace(~r/\s*\d+\s*$/, "")

      %{"idclub" => id, "name" => name, "teams" => teams}
    end)
  end
end
