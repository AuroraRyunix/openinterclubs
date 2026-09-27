defmodule OpenInterclubs.Schedule do
  @moduledoc """
  The fixed KBSB round-robin schedules by pairing number, as used by the
  KBSB backend (`ptable12` for 12-team series over 11 rounds, `ptable10`
  for division 6: 10 teams over 9 rounds).

  The public API no longer returns encounters for rounds that haven't been
  played, so we rebuild them from the teams' pairing numbers.
  """

  @rounds12 [
    [{1, 12}, {2, 11}, {3, 10}, {4, 9}, {5, 8}, {6, 7}],
    [{12, 7}, {8, 6}, {9, 5}, {10, 4}, {11, 3}, {1, 2}],
    [{2, 12}, {3, 1}, {4, 11}, {5, 10}, {6, 9}, {7, 8}],
    [{12, 8}, {9, 7}, {10, 6}, {11, 5}, {1, 4}, {2, 3}],
    [{3, 12}, {4, 2}, {5, 1}, {6, 11}, {7, 10}, {8, 9}],
    [{12, 9}, {10, 8}, {11, 7}, {1, 6}, {2, 5}, {3, 4}],
    [{4, 12}, {5, 3}, {6, 2}, {7, 1}, {8, 11}, {9, 10}],
    [{12, 10}, {11, 9}, {1, 8}, {2, 7}, {3, 6}, {4, 5}],
    [{5, 12}, {6, 4}, {7, 3}, {8, 2}, {9, 1}, {10, 11}],
    [{12, 11}, {1, 10}, {2, 9}, {3, 8}, {4, 7}, {5, 6}],
    [{6, 12}, {7, 5}, {8, 4}, {9, 3}, {10, 2}, {11, 1}]
  ]

  @rounds10 [
    [{1, 10}, {2, 9}, {3, 8}, {4, 7}, {5, 6}],
    [{10, 6}, {7, 5}, {8, 4}, {9, 3}, {1, 2}],
    [{2, 10}, {3, 1}, {4, 9}, {5, 8}, {6, 7}],
    [{10, 7}, {8, 6}, {9, 5}, {1, 4}, {2, 3}],
    [{3, 10}, {4, 2}, {5, 1}, {6, 9}, {7, 8}],
    [{10, 8}, {9, 7}, {1, 6}, {2, 5}, {3, 4}],
    [{4, 10}, {5, 3}, {6, 2}, {7, 1}, {8, 9}],
    [{10, 9}, {1, 8}, {2, 7}, {3, 6}, {4, 5}],
    [{5, 10}, {6, 4}, {7, 3}, {8, 2}, {9, 1}]
  ]

  @doc "Pairings of a round for a series with `teams` teams."
  def pairings(round, teams \\ 12)
  def pairings(round, teams) when teams <= 10 and round in 1..9, do: Enum.at(@rounds10, round - 1)
  def pairings(round, teams) when teams > 10 and round in 1..11, do: Enum.at(@rounds12, round - 1)
  def pairings(_, _), do: []

  @doc "Fill in encounters for rounds the API returned without any."
  def complete(%{"rounds" => rounds, "teams" => teams} = series) do
    by_pnr = Map.new(teams, &{&1["pairingnumber"], &1})

    rounds =
      Enum.map(rounds, fn
        %{"encounters" => [_ | _]} = r ->
          r

        r ->
          encounters =
            for {h, v} <- pairings(r["round"], length(teams)),
                home = by_pnr[h],
                visit = by_pnr[v] do
              %{
                "icclub_home" => home["idclub"],
                "icclub_visit" => visit["idclub"],
                "pairingnr_home" => h,
                "pairingnr_visit" => v,
                "games" => [],
                "played" => false
              }
            end

          Map.put(r, "encounters", encounters)
      end)

    %{series | "rounds" => rounds}
  end

  def complete(series), do: series
end
