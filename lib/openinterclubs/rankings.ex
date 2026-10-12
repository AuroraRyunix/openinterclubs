defmodule OpenInterclubs.Rankings do
  @moduledoc "The player ranking list, shared by the Spelers page and its Excel export."

  alias OpenInterclubs.Season

  @sorts ~w(tpr diff w_we score rating played)
  def sorts, do: @sorts

  @doc "All players matching `min` games and name `q`, sorted by `sort` (descending)."
  def list(%{"min" => min, "sort" => sort, "q" => q}) do
    q = q |> to_string() |> String.trim() |> String.downcase()
    field = if sort in @sorts, do: String.to_existing_atom(sort), else: :tpr

    Season.players()
    |> Enum.filter(&(&1.played >= min))
    |> Enum.filter(&(q == "" or String.contains?(String.downcase(&1.name), q)))
    |> Enum.sort_by(&{Map.get(&1, field) || -9999, &1.rating}, :desc)
  end
end
