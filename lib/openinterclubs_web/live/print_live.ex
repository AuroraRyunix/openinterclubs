defmodule OpenInterclubsWeb.PrintLive do
  @moduledoc "All fiches of one club for one round, one per printed page."
  use OpenInterclubsWeb, :live_view

  alias OpenInterclubs.{Fiche, Kbsb}
  import OpenInterclubsWeb.FicheComponents

  @impl true
  def mount(%{"idclub" => idclub, "round" => round} = params, session, socket) do
    round = String.to_integer(round)
    filled = params["filled"] == "1"

    {name, fiches} =
      case Kbsb.club(idclub) do
        {:ok, club} ->
          fiches =
            club["teams"]
            |> Enum.map(&Fiche.fetch(&1, round))
            |> Enum.map(
              &with_club_lineups(&1, session["kbsb_token"], session["kbsb_club"], round)
            )
            |> Enum.flat_map(fn
              {:ok, f} -> [Fiche.fill(f, if(filled, do: :all, else: :home))]
              _ -> []
            end)

          {club["name"], fiches}

        _ ->
          {idclub, []}
      end

    {:ok,
     assign(socket,
       name: name,
       idclub: idclub,
       round: round,
       fiches: with_filenames(fiches, name, idclub, round),
       zip: "#{slug(name)}_#{idclub}_R#{pad(round)}.zip",
       filled: filled
     )}
  end

  # Own club only, own side only; see FicheLive.
  defp with_club_lineups({:ok, fiche}, token, club, round)
       when is_binary(token) and is_integer(club) do
    with side when side != nil <- Fiche.own_side(fiche, club),
         {:ok, series} <- OpenInterclubs.Kbsb.club_series(token, club, round) do
      {:ok, Fiche.merge_club_series(fiche, series, club)}
    else
      _ -> {:ok, fiche}
    end
  end

  defp with_club_lineups(result, _token, _club, _round), do: result

  # clubname_clubnumber_RXX_series.pdf; when a club has two teams in the
  # same series the team number is added so the files don't overwrite.
  defp with_filenames(fiches, name, idclub, round) do
    base = fn f -> "#{slug(name)}_#{idclub}_R#{pad(round)}_#{series(f)}" end
    counts = Enum.frequencies_by(fiches, base)

    Enum.map(fiches, fn f ->
      own = if to_string(f.home.idclub) == to_string(idclub), do: f.home, else: f.visit

      number =
        case Regex.run(~r/(\d+)\s*$/, own.name || "") do
          [_, n] -> n
          _ -> "1"
        end

      file =
        if counts[base.(f)] > 1, do: "#{base.(f)}_ploeg#{number}.pdf", else: "#{base.(f)}.pdf"

      {f, file}
    end)
  end

  defp series(%{division: 1}), do: "1"
  defp series(f), do: "#{f.division}#{f.index}"

  defp pad(n), do: n |> to_string() |> String.pad_leading(2, "0")

  # "Jean Jaurès Gent" -> "Jean_Jaures_Gent"
  defp slug(name) do
    name
    |> to_string()
    |> String.normalize(:nfd)
    |> String.replace(~r/[^A-Za-z0-9]+/, "_")
    |> String.trim("_")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="screen-only flex items-center gap-3 mb-6">
        <.link class="btn" navigate={~p"/fiche?#{%{club: @idclub, round: @round}}"}>← Terug</.link>
        <.link
          id="toggle-filled"
          class="btn"
          navigate={~p"/print/#{@idclub}/#{@round}?#{if(@filled, do: %{}, else: %{filled: 1})}"}
        >
          {if @filled, do: "Uitploeg leeg laten", else: "Ook uitploeg invullen"}
        </.link>
        <button class="btn btn-primary" onclick="window.print()">Alles afdrukken</button>
        <button :if={@fiches != []} id="export-pdfs" class="btn" phx-hook="ExportPdfs" data-zip={@zip}>
          Download als aparte PDF's
        </button>
        <span>{@name} — ronde {@round}: {length(@fiches)} fiche(s)</span>
      </div>
      <p :if={@fiches == []}>Geen ontmoetingen gevonden.</p>
      <div :for={{f, file} <- @fiches} class="page" data-filename={file}>
        <.fiche fiche={f} />
      </div>
    </Layouts.app>
    """
  end
end
