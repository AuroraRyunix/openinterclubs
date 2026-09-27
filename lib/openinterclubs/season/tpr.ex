defmodule OpenInterclubs.Season.Tpr do
  @moduledoc "Tournament performance rating using the FIDE dp table."

  # dp for 0..50 %; 51..100 % mirror these values.
  @dp {-800, -677, -589, -538, -501, -470, -444, -422, -401, -383, -366, -351, -336, -322, -309,
       -296, -284, -273, -262, -251, -240, -230, -220, -211, -202, -193, -184, -175, -166, -158,
       -149, -141, -133, -125, -117, -110, -102, -95, -87, -80, -72, -65, -57, -50, -43, -36, -29,
       -21, -14, -7, 0}

  @doc "dp for a score percentage (0..100)."
  def dp(pct) when pct <= 50, do: elem(@dp, pct)
  def dp(pct), do: -elem(@dp, 100 - pct)

  @doc "Expected score against an opponent (Elo formula, 400-point cap as FIDE)."
  def expected(own, opp) when is_integer(own) and is_integer(opp) and own > 0 and opp > 0 do
    diff = max(min(opp - own, 400), -400)
    1 / (1 + :math.pow(10, diff / 400))
  end

  def expected(_, _), do: nil

  @doc """
  Estimated FIDE rating change for a score against expectation. K is 20,
  or 10 from 2400 FIDE; juniors (K=40) can't be told apart from the data.
  """
  def fide_change(fide, w_we) when is_integer(fide) and fide > 0 do
    k = if fide >= 2400, do: 10, else: 20
    Float.round(k * w_we, 1)
  end

  def fide_change(_, _), do: nil

  @doc "TPR from opponent ratings and the score against them; nil when no games."
  def tpr([], _score), do: nil

  def tpr(opponent_ratings, score) do
    avg = Enum.sum(opponent_ratings) / length(opponent_ratings)
    pct = round(score / length(opponent_ratings) * 100)
    round(avg + dp(pct))
  end
end
