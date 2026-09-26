defmodule OpenInterclubsWeb.FicheLive do
  @moduledoc "Pick club → team → round and get a pre-filled, printable result sheet."
  use OpenInterclubsWeb, :live_view

  alias OpenInterclubs.{ClubLineups, Fiche, Kbsb}
  import OpenInterclubsWeb.FicheComponents

  @rounds 1..11

  @impl true
  def mount(_params, session, socket) do
    clubs =
      case Kbsb.clubs() do
        {:ok, clubs} -> Enum.filter(clubs, &(&1["teams"] != []))
        _ -> []
      end

    {:ok,
     assign(socket,
       clubs: clubs,
       rounds: @rounds,
       club: nil,
       team: nil,
       fiche: nil,
       token: session["kbsb_token"],
       user: %{token: session["kbsb_token"], idnumber: session["kbsb_idnumber"]},
       own_side: nil,
       kbsb_user: session["kbsb_user"]
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    club = find_club(socket.assigns.clubs, params["club"])
    team = club && Enum.find(club["teams"], &(&1["name"] == params["team"]))
    round = parse_round(params["round"])

    socket = assign(socket, club: club, team: team, round: round, fiche: nil)

    socket =
      if team && round do
        case Fiche.fetch(team, round) do
          {:ok, fiche} ->
            {fiche, side} = ClubLineups.merge(fiche, socket.assigns.user, club["idclub"])
            fiche = if side, do: Fiche.fill(fiche, side), else: fiche
            assign(socket, fiche: fiche, own_side: side)

          {:error, :no_encounter} ->
            put_flash(socket, :error, "Geen ontmoeting in ronde #{round}.")

          {:error, _} ->
            put_flash(socket, :error, "KBSB API niet bereikbaar, probeer later opnieuw.")
        end
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("select", params, socket) do
    case resolve_club(socket.assigns.clubs, params["club"]) do
      # Still typing: nothing matches yet, keep the current selection.
      :nomatch -> {:noreply, socket}
      club_id -> select(Map.put(params, "club", club_id), socket)
    end
  end

  def handle_event("set_player", %{"board" => board, "side" => side, "idnumber" => id}, socket)
      when side in ["home", "visit"] do
    id = if id == "", do: nil, else: String.to_integer(id)

    fiche =
      Fiche.set_player(
        socket.assigns.fiche,
        String.to_integer(board),
        String.to_existing_atom(side),
        id
      )

    {:noreply, assign(socket, fiche: fiche)}
  end

  def handle_event("fill", _params, socket) do
    %{team: team, round: round, fiche: fiche, club: club} = socket.assigns

    case Fiche.fetch(team, round, fresh: true) do
      {:ok, fresh} ->
        {fresh, side} = ClubLineups.merge(fresh, socket.assigns.user, club["idclub"])

        cond do
          is_nil(side) ->
            {:noreply,
             put_flash(
               socket,
               :info,
               "Je kan enkel de opstelling invullen van een club die je beheert."
             )}

          not Fiche.api_lineup?(fresh, side) ->
            {:noreply, put_flash(socket, :info, "Nog geen opstelling ingediend op de KBSB-site.")}

          true ->
            fiche = fiche |> Fiche.refresh_api(fresh) |> Fiche.fill(side)
            {:noreply, assign(socket, fiche: fiche, own_side: side)}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "KBSB API niet bereikbaar, probeer later opnieuw.")}
    end
  end

  def handle_event("clear", %{"side" => side}, socket) when side in ["home", "visit", "all"] do
    {:noreply,
     assign(socket, fiche: Fiche.clear(socket.assigns.fiche, String.to_existing_atom(side)))}
  end

  defp select(params, socket) do
    params =
      params
      |> Map.take(["club", "team", "round"])
      |> Enum.reject(fn {_, v} -> v in [nil, ""] end)
      |> Map.new()

    # Changing club invalidates the team choice.
    params =
      if socket.assigns.club && params["club"] != to_string(socket.assigns.club["idclub"]),
        do: Map.delete(params, "team"),
        else: params

    {:noreply, push_patch(socket, to: ~p"/fiche?#{params}")}
  end

  defp club_label(club), do: "#{club["name"]} (#{club["idclub"]})"

  # Accepts "Name (123)" from the datalist, a bare club number, or an exact name.
  defp resolve_club(_clubs, text) when text in [nil, ""], do: ""

  defp resolve_club(clubs, text) do
    text = String.trim(text)

    id =
      case Regex.run(~r/(?:^|\()(\d+)\)?$/, text) do
        [_, id] ->
          id

        _ ->
          Enum.find_value(
            clubs,
            &(String.downcase(&1["name"]) == String.downcase(text) && to_string(&1["idclub"]))
          )
      end

    if id && find_club(clubs, id), do: id, else: :nomatch
  end

  defp find_club(_clubs, nil), do: nil
  defp find_club(clubs, id), do: Enum.find(clubs, &(to_string(&1["idclub"]) == id))

  defp parse_round(nil), do: nil

  defp parse_round(r) do
    case Integer.parse(r) do
      {n, ""} when n in @rounds -> n
      _ -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <form id="select-form" phx-change="select" class="screen-only flex flex-wrap gap-3 mb-6">
        <input
          id="club-search"
          name="club"
          list="club-list"
          class="input w-80"
          placeholder="Zoek club op naam of nummer…"
          autocomplete="off"
          phx-debounce="200"
          value={@club && club_label(@club)}
        />
        <datalist id="club-list">
          <option :for={c <- @clubs} value={club_label(c)} />
        </datalist>
        <select :if={@club} name="team" class="select">
          <option value="">Ploeg…</option>
          {Phoenix.HTML.Form.options_for_select(
            Enum.map(
              @club["teams"],
              &{"#{&1["name"]} — afd. #{&1["division"]}#{&1["index"]}", &1["name"]}
            ),
            @team && @team["name"]
          )}
        </select>
        <select :if={@club} name="round" class="select">
          <option value="">Ronde…</option>
          {Phoenix.HTML.Form.options_for_select(Enum.map(@rounds, &{"Ronde #{&1}", &1}), @round)}
        </select>
      </form>

      <div :if={@club && @round} class="screen-only flex gap-3 mb-4">
        <button
          :if={@fiche && @own_side}
          id="fill-all"
          class="btn"
          phx-click="fill"
        >
          Mijn opstelling invullen
        </button>
        <button :if={@fiche} id="clear-all" class="btn" phx-click="clear" phx-value-side="all">
          Alles wissen
        </button>
        <button :if={@fiche} class="btn btn-primary" onclick="window.print()">Afdrukken / PDF</button>
        <.link class="btn" navigate={~p"/print/#{@club["idclub"]}/#{@round}"}>
          Alle ploegen van {@club["name"]} — ronde {@round}
        </.link>
      </div>

      <p class="screen-only mb-4 text-sm">
        <%= if @kbsb_user do %>
          Aangemeld bij de KBSB als <b>{@kbsb_user}</b>.
          <.form for={%{}} action={~p"/logout"} method="post" class="inline">
            <button id="logout" class="underline">Afmelden</button>
          </.form>
        <% else %>
          Opstellingen zijn niet meer publiek.
          <.link href={~p"/login?#{%{return_to: "/fiche"}}"} id="login-link" class="underline">
            Meld je aan met je KBSB-login
          </.link>
          om je eigen opstelling in te vullen.
        <% end %>
      </p>

      <p :if={@fiche} class="screen-only text-sm opacity-70 mb-2">
        Je eigen ploeg wordt ingevuld met de opstelling van de KBSB-site, thuis of uit;
        de tegenstander blijft leeg. „Mijn opstelling invullen” haalt de laatste versie op.
      </p>

      <.fiche :if={@fiche} fiche={@fiche} editable />
    </Layouts.app>
    """
  end
end
