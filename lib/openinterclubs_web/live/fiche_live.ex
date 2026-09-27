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
            case ClubLineups.merge(fiche, socket.assigns.user, club["idclub"]) do
              {:ok, fiche, side} ->
                assign(socket, fiche: Fiche.fill(fiche, side), own_side: side)

              {:error, reason} when reason in [:not_logged_in, :not_playing] ->
                assign(socket, fiche: fiche, own_side: nil)

              {:error, reason} ->
                socket
                |> assign(fiche: fiche, own_side: nil)
                |> put_flash(:error, ClubLineups.error_message(reason, club["name"]))
            end

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
        case ClubLineups.merge(fresh, socket.assigns.user, club["idclub"]) do
          {:ok, fresh, side} ->
            if Fiche.api_lineup?(fresh, side) do
              fiche = fiche |> Fiche.refresh_api(fresh) |> Fiche.fill(side)
              {:noreply, assign(socket, fiche: fiche, own_side: side)}
            else
              {:noreply,
               put_flash(socket, :info, t("Nog geen opstelling ingediend op de KBSB-site."))}
            end

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, ClubLineups.error_message(reason, club["name"]))}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "KBSB API niet bereikbaar, probeer later opnieuw.")}
    end
  end

  def handle_event("clear", %{"side" => side}, socket) when side in ["home", "visit", "all"] do
    {:noreply,
     assign(socket, fiche: Fiche.clear(socket.assigns.fiche, String.to_existing_atom(side)))}
  end

  # Phones: one row per board with both players, instead of the small
  # dropdowns inside the sheet (which then only shows names).
  attr :fiche, :any, required: true

  defp mobile_editor(assigns) do
    ~H"""
    <div id="mobile-editor" class="screen-only mb-4 space-y-2 md:hidden">
      <div class="grid grid-cols-[1.5rem_1fr_1fr] gap-2 px-1 text-xs font-semibold opacity-60">
        <span></span>
        <span class="truncate">{@fiche.home.name}</span>
        <span class="truncate">{@fiche.visit.name}</span>
      </div>
      <div
        :for={b <- @fiche.boards}
        class="grid grid-cols-[1.5rem_1fr_1fr] items-center gap-2 rounded-xl bg-base-200 p-2"
      >
        <span class="text-center text-sm font-bold opacity-60">{b.board}</span>
        <form :for={side <- [:home, :visit]} phx-change="set_player" id={"m-board-#{b.board}-#{side}"}>
          <input type="hidden" name="board" value={b.board} />
          <input type="hidden" name="side" value={side} />
          <select
            name="idnumber"
            class="w-full rounded-lg border border-base-300 bg-base-100 px-2 py-2 text-sm"
          >
            <option value="">—</option>
            {Phoenix.HTML.Form.options_for_select(
              Map.fetch!(@fiche, side).options,
              (current = Map.get(b, side)) && current.idnumber
            )}
          </select>
        </form>
      </div>
      <p class="px-1 text-xs opacity-60">{t("Veeg opzij om de volledige fiche te zien.")}</p>
    </div>
    """
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
      <form id="select-form" phx-change="select" class="screen-only mb-6 flex flex-wrap gap-3">
        <input
          id="club-search"
          name="club"
          list="club-list"
          class="input w-full sm:w-80"
          placeholder={t("Zoek club op naam of nummer…")}
          autocomplete="off"
          phx-debounce="200"
          value={@club && club_label(@club)}
        />
        <datalist id="club-list">
          <option :for={c <- @clubs} value={club_label(c)} />
        </datalist>
        <select :if={@club} name="team" class="select">
          <option value="">{t("Ploeg…")}</option>
          {Phoenix.HTML.Form.options_for_select(
            Enum.map(
              @club["teams"],
              &{"#{&1["name"]} — afd. #{&1["division"]}#{&1["index"]}", &1["name"]}
            ),
            @team && @team["name"]
          )}
        </select>
        <select :if={@club} name="round" class="select">
          <option value="">{t("Ronde…")}</option>
          {Phoenix.HTML.Form.options_for_select(
            Enum.map(@rounds, &{t("Ronde %{n}", n: &1), &1}),
            @round
          )}
        </select>
      </form>

      <div :if={@club && @round} class="screen-only mb-4 flex flex-wrap gap-3">
        <button
          :if={@fiche && @own_side}
          id="fill-all"
          class="btn"
          phx-click="fill"
        >
          {t("Mijn opstelling invullen")}
        </button>
        <button :if={@fiche} id="clear-all" class="btn" phx-click="clear" phx-value-side="all">
          {t("Alles wissen")}
        </button>
        <button :if={@fiche} class="btn btn-primary" onclick="window.print()">{t("Afdrukken / PDF")}</button>
        <.link class="btn" navigate={~p"/print/#{@club["idclub"]}/#{@round}"}>
          {t("Alle ploegen van %{club} — ronde %{r}", club: @club["name"], r: @round)}
        </.link>
      </div>

      <p class="screen-only mb-4 text-sm">
        <%= if @kbsb_user do %>
          {t("Aangemeld bij de KBSB als")} <b>{@kbsb_user}</b>.
          <.link
            :if={@club && @round}
            navigate={~p"/beheer/#{@club["idclub"]}/#{@round}"}
            id="to-admin"
            class="underline"
          >
            {t("Clubbeheer")}
          </.link>
          <.form for={%{}} action={~p"/logout"} method="post" class="inline">
            <button id="logout" class="underline">{t("Afmelden")}</button>
          </.form>
        <% else %>
          {t("Opstellingen zijn niet meer publiek.")}
          <.link href={~p"/login?#{%{return_to: "/fiche"}}"} id="login-link" class="underline">
            {t("Meld je aan met je KBSB-login")}
          </.link>
          {t("om je eigen opstelling in te vullen.")}
        <% end %>
      </p>

      <p :if={@fiche} class="screen-only text-sm opacity-70 mb-2">
        {t(
          "Je eigen ploeg wordt ingevuld met de opstelling van de KBSB-site, thuis of uit; de tegenstander blijft leeg."
        )}
      </p>

      <.mobile_editor :if={@fiche} fiche={@fiche} />
      <.fiche :if={@fiche} fiche={@fiche} editable />
    </Layouts.app>
    """
  end
end
