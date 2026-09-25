defmodule OpenInterclubs.Season.Result do
  @moduledoc """
  Game results as reported by the KBSB API, always from the home team's
  point of view ("1-0" = the home player won, whatever the colour).
  """

  @type t :: :home | :draw | :visit | :home_ff | :visit_ff | :both_ff | nil

  @doc "Parse an API game, honouring an arbiter's `overruled` value."
  def parse(%{"overruled" => o} = g) when o not in [nil, "", "NOR"],
    do: parse_string(o) || parse(Map.delete(g, "overruled"))

  def parse(%{"result" => r}), do: parse_string(r)
  def parse(_), do: nil

  defp parse_string(s) when is_binary(s) do
    case s |> String.replace(" ", "") |> String.upcase() do
      "1-0" -> :home
      "0-1" -> :visit
      d when d in ["½-½", "1/2-1/2", "0.5-0.5"] -> :draw
      "1-0FF" -> :home_ff
      "0-1FF" -> :visit_ff
      "0-0FF" -> :both_ff
      _ -> nil
    end
  end

  defp parse_string(_), do: nil

  def score(r, :home) when r in [:home, :home_ff], do: 1.0
  def score(r, :visit) when r in [:visit, :visit_ff], do: 1.0
  def score(:draw, _), do: 0.5
  def score(nil, _), do: nil
  def score(_, _), do: 0.0

  def forfeit?(r), do: r in [:home_ff, :visit_ff, :both_ff]

  @doc "Short label from one side's perspective: 1, ½, 0, 1F, 0F."
  def label(nil, _), do: ""

  def label(r, side) do
    s = score(r, side)
    base = if s == 0.5, do: "½", else: s |> trunc() |> to_string()
    if forfeit?(r), do: base <> "F", else: base
  end

  @doc "Result as written on the fiche: 1-0, ½-½, 0-1, 1-0 F…"
  def display(nil), do: ""
  def display(r), do: label(r, :home) <> "-" <> label(r, :visit)
end
