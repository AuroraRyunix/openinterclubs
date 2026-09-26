defmodule OpenInterclubs.ClubLineups do
  @moduledoc """
  Fills a fiche with the lineup of ONE club: the club the user is looking at
  (selected on the fiche, or the club of the print/ZIP page).

  That club's lineup is only used when the logged-in member is listed in the
  club's public role list (club admin, interclub admin or captain), and only
  that club's own side of the encounter is ever touched. The KBSB's own
  access checks are not relied on: its club endpoints hand out other clubs'
  data too.
  """

  alias OpenInterclubs.{Fiche, Kbsb}

  @doc "Whether the member (by idnumber) holds a role in `idclub`."
  def manages?(idnumber, idclub) when is_integer(idnumber) and is_integer(idclub) do
    case Kbsb.club_role_members(idclub) do
      {:ok, members} -> idnumber in members
      _ -> false
    end
  end

  def manages?(_, _), do: false

  @doc """
  Merge `club`'s own lineup into the fiche. Returns `{fiche, side}` where
  `side` is the side that may be filled (`nil` when not allowed or `club`
  doesn't play this encounter). If a club plays itself, only home counts.
  """
  def merge(%Fiche{} = fiche, %{token: token, idnumber: idnumber}, club)
      when is_binary(token) and is_integer(club) do
    with side when side != nil <- Fiche.own_side(fiche, club),
         true <- manages?(idnumber, club),
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
