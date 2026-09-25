defmodule OpenInterclubsWeb.PrintLive do
  @moduledoc "All fiches of one club for one round, one per printed page."
  use OpenInterclubsWeb, :live_view

  alias OpenInterclubs.{Fiche, Kbsb}
  import OpenInterclubsWeb.FicheComponents

  @impl true
  def mount(%{"idclub" => idclub, "round" => round} = params, _session, socket) do
    round = String.to_integer(round)
    filled = params["filled"] == "1"

    {name, fiches} =
      case Kbsb.club(idclub) do
        {:ok, club} ->
          fiches =
            club["teams"]
            |> Enum.map(&Fiche.fetch(&1, round))
            |> Enum.flat_map(fn
              {:ok, f} -> [if(filled, do: Fiche.fill(f, :all), else: f)]
              _ -> []
            end)

          {club["name"], fiches}

        _ ->
          {idclub, []}
      end

    {:ok,
     assign(socket, name: name, idclub: idclub, round: round, fiches: fiches, filled: filled)}
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
          {if @filled, do: "Leeg afdrukken", else: "Met KBSB-opstellingen"}
        </.link>
        <button class="btn btn-primary" onclick="window.print()">Alles afdrukken</button>
        <span>{@name} — ronde {@round}: {length(@fiches)} fiche(s)</span>
      </div>
      <p :if={@fiches == []}>Geen ontmoetingen gevonden.</p>
      <div :for={f <- @fiches} class="page">
        <.fiche fiche={f} />
      </div>
    </Layouts.app>
    """
  end
end
