defmodule OpenInterclubs.ClubLineups do
  @moduledoc """
  Fills a fiche with the lineup of ONE club: the club the user is looking at
  (selected on the fiche, or the club of the print/ZIP page).

  That club's lineup is only used when the logged-in member holds a club
  role there (club admin, interclub admin or captain): listed in the club's
  public role list, or, when a club doesn't publish one, confirmed by the
  KBSB access check. Only that club's own side of the encounter is ever
  touched; the other club is never checked or requested.
  """

  alias OpenInterclubs.{Fiche, Kbsb}

  @doc "Whether the logged-in user holds a role in `idclub`."
  def manages?(%{token: token, idnumber: idnumber}, idclub)
      when is_binary(token) and is_integer(idclub) do
    case Kbsb.club_role_members(idclub) do
      {:ok, [_ | _] = members} -> idnumber in members
      # Club publishes no role list: ask the KBSB for this club only.
      _ -> Kbsb.club_access?(token, idclub)
    end
  end

  def manages?(_, _), do: false

  @doc """
  Merge `club`'s own lineup into the fiche. Returns `{fiche, side}` where
  `side` is the side that may be filled (`nil` when not allowed or `club`
  doesn't play this encounter). If a club plays itself, only home counts.
  """
  def merge(%Fiche{} = fiche, %{token: token} = user, club)
      when is_binary(token) and is_integer(club) do
    with side when side != nil <- Fiche.own_side(fiche, club),
         true <- manages?(user, club),
         {:ok, series} <- Kbsb.club_series(token, club, fiche.round) do
      {Fiche.merge_club_series(fiche, series, club), side}
    else
      _ -> {fiche, nil}
    end
  end

  def merge(fiche, _user, _club), do: {fiche, nil}

  @doc "Merge and fill in one go (print page, ZIP export)."
  def fill(fiche, user, club) do
    case merge(fiche, user, club) do
      {fiche, nil} -> fiche
      {fiche, side} -> Fiche.fill(fiche, side)
    end
  end
end
