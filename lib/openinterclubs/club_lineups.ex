defmodule OpenInterclubs.ClubLineups do
  @moduledoc """
  Fills a fiche with the lineup of ONE club: the club the user selected
  (on the fiche, or the club of the print/ZIP page).

  Access is checked with the KBSB for that club only
  (`clubs/clb/club/{idclub}/access/{role}`; superusers pass for every club).
  Only that club's own side of the encounter is ever filled, never the
  opponent's, whatever the user has access to.
  """

  alias OpenInterclubs.{Fiche, Kbsb}

  @doc """
  Merge `club`'s own lineup into the fiche.

  Returns `{:ok, fiche, side}`, or `{:error, reason}` with reason
  `:not_logged_in`, `:not_playing` (club isn't in this encounter),
  `:no_access` or an API error.
  """
  def merge(%Fiche{} = fiche, %{token: token}, club) when is_binary(token) and is_integer(club) do
    with {:side, side} when side != nil <- {:side, Fiche.own_side(fiche, club)},
         {:access, true} <- {:access, Kbsb.club_access?(token, club)},
         {:ok, series} <- Kbsb.club_series(token, club, fiche.round) do
      {:ok, Fiche.merge_club_series(fiche, series, club), side}
    else
      {:side, nil} -> {:error, :not_playing}
      {:access, false} -> {:error, :no_access}
      {:error, reason} -> {:error, reason}
    end
  end

  def merge(_fiche, _user, _club), do: {:error, :not_logged_in}

  @doc "Merge and fill in one go (print page, ZIP export)."
  def fill(fiche, user, club) do
    case merge(fiche, user, club) do
      {:ok, fiche, side} -> {:ok, Fiche.fill(fiche, side)}
      {:error, reason} -> {:error, reason, fiche}
    end
  end

  def error_message(:no_access, club_name),
    do: "Je hebt geen toegang tot de opstellingen van #{club_name}."

  def error_message(:unauthorized, _), do: "Je KBSB-sessie is verlopen; meld je opnieuw aan."
  def error_message(_, _), do: "De opstelling kon niet opgehaald worden bij de KBSB."
end
