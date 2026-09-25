defmodule OpenInterclubs.ClubLineups do
  @moduledoc """
  Fills a fiche with lineups from the KBSB club endpoint, but only for the
  side(s) whose club the logged-in user manages (checked with the KBSB via
  `Kbsb.club_access?/2`). The club endpoint returns other clubs' lineups
  too; those are never used.
  """

  alias OpenInterclubs.{Fiche, Kbsb}

  @doc """
  Returns `{fiche, access}` where `access` memoizes idclub => boolean so a
  page with several fiches only asks the KBSB once per club.
  """
  def apply(fiche, token, access \\ %{})

  def apply(%Fiche{} = fiche, token, access) when is_binary(token) do
    Enum.reduce([fiche.home.idclub, fiche.visit.idclub], {fiche, access}, fn club, {f, acc} ->
      allowed = Map.get_lazy(acc, club, fn -> Kbsb.club_access?(token, club) end)
      acc = Map.put(acc, club, allowed)

      with true <- allowed,
           {:ok, series} <- Kbsb.club_series(token, club, f.round) do
        {Fiche.merge_club_series(f, series, club), acc}
      else
        _ -> {f, acc}
      end
    end)
  end

  def apply(fiche, _token, access), do: {fiche, access}
end
