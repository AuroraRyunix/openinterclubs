defmodule OpenInterclubsWeb.ClubAdminLive do
  @moduledoc """
  Page for a club's IC admin: all teams of the club in a round, lineups
  (check with the KBSB rules, submit) and, once the round is open, results.
  Only for users the KBSB grants access to that club.
  """
  use OpenInterclubsWeb, :live_view

  alias OpenInterclubs.{ClubAdmin, Fiche, Kbsb}

  @impl true
  def mount(%{"idclub" => idclub, "round" => round}, session, socket) do
    idclub = String.to_integer(idclub)
    round = String.to_integer(round)
    token = session["kbsb_token"]

    socket =
      assign(socket,
        idclub: idclub,
        round: round,
        token: token,
        idnumber: session["kbsb_idnumber"],
        confirm: MapSet.new(),
        errors: nil,
        saved_at: nil,
        page_title: "Mgmt"
      )

    cond do
      is_nil(token) ->
        {:ok, assign(socket, state: :login)}

      not Kbsb.club_access?(token, idclub) ->
        {:ok, assign(socket, state: :forbidden)}

      true ->
        {:ok, socket |> assign(state: :ok) |> load()}
    end
  end

  defp load(socket) do
    %{token: token, idclub: idclub, round: round} = socket.assigns

    club =
      case Kbsb.club(idclub) do
        {:ok, c} -> c
        _ -> %{"name" => to_string(idclub), "players" => []}
      end

    case Kbsb.club_series(token, idclub, round) do
      {:ok, series} ->
        teams = ClubAdmin.teams(series, idclub, round)
        open = Enum.any?(teams, &ClubAdmin.round_open?(&1.date))

        # Once the round is open, show the opponents' names too (their
        # player lists are public).
        opponents =
          if open,
            do:
              teams |> Enum.map(& &1.opponent.idclub) |> Enum.uniq() |> Enum.flat_map(&players/1),
            else: []

        assign(socket,
          club: club,
          options: Fiche.player_options(club["players"]),
          names:
            Map.new(
              (club["players"] || []) ++ opponents,
              &{&1["idnumber"], "#{&1["last_name"]} #{&1["first_name"]}"}
            ),
          teams: teams,
          open: open,
          page_title: "Mgmt #{club["name"]}"
        )

      {:error, reason} ->
        socket
        |> assign(club: club, options: [], names: %{}, teams: [], open: false)
        |> put_flash(:error, "Ophalen bij de KBSB mislukt (#{inspect(reason)}).")
    end
  end

  @impl true
  def handle_event("set_player", %{"team" => key, "board" => b, "idnumber" => id}, socket) do
    id = if id == "", do: nil, else: String.to_integer(id)
    teams = ClubAdmin.set_player(socket.assigns.teams, key, String.to_integer(b), id)
    {:noreply, assign(socket, teams: teams, errors: nil)}
  end

  def handle_event("set_result", %{"team" => key, "board" => b, "result" => r}, socket) do
    if r in ClubAdmin.result_options() do
      teams = ClubAdmin.set_result(socket.assigns.teams, key, String.to_integer(b), r)
      {:noreply, assign(socket, teams: teams)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("validate", _, socket) do
    %{token: token, idclub: idclub, round: round, teams: teams} = socket.assigns

    case Kbsb.validate_planning(token, ClubAdmin.planning(idclub, round, teams)) do
      {:ok, errors} ->
        {:noreply, assign(socket, errors: errors)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Controle mislukt (#{inspect(reason)}).")}
    end
  end

  def handle_event("submit", _, socket) do
    %{token: token, idclub: idclub, round: round, teams: teams} = socket.assigns
    planning = ClubAdmin.planning(idclub, round, teams)

    with {:ok, []} <- Kbsb.validate_planning(token, planning),
         :ok <- Kbsb.save_planning(token, planning) do
      {:noreply,
       socket
       |> load()
       |> assign(errors: [], saved_at: DateTime.utc_now())
       |> put_flash(:info, "Opstellingen ingediend bij de KBSB.")}
    else
      {:ok, errors} ->
        {:noreply,
         socket
         |> assign(errors: errors)
         |> put_flash(:error, "Niet ingediend: los eerst de fouten op.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Indienen mislukt (#{inspect(reason)}).")}
    end
  end

  def handle_event("toggle_confirm", %{"team" => key}, socket) do
    confirm = socket.assigns.confirm

    confirm =
      if MapSet.member?(confirm, key),
        do: MapSet.delete(confirm, key),
        else: MapSet.put(confirm, key)

    {:noreply, assign(socket, confirm: confirm)}
  end

  def handle_event("save_results", %{"team" => key}, socket) do
    %{token: token, teams: teams, confirm: confirm, idnumber: idnumber} = socket.assigns
    team = Enum.find(teams, &(&1.key == key))
    confirm_by = if MapSet.member?(confirm, key) and is_integer(idnumber), do: idnumber

    case team && Kbsb.save_results(token, [ClubAdmin.result_item(team, confirm_by: confirm_by)]) do
      :ok ->
        {:noreply, socket |> load() |> put_flash(:info, "Uitslag van #{team.name} opgeslagen.")}

      nil ->
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Opslaan mislukt (#{inspect(reason)}).")}
    end
  end

  defp team_errors(nil, _), do: []

  defp team_errors(errors, team) do
    Enum.filter(
      errors,
      &(&1["division"] == team.division and (&1["index"] || "") == team.index and
          &1["pnr_offender"] == team.pairingnumber)
    )
  end

  defp board_error?(errors, board), do: Enum.any?(errors, &(&1["boardnr"] == board))

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <%= case @state do %>
        <% :login -> %>
          <p>
            Meld je eerst <.link
              href={~p"/login?#{%{return_to: "/mgmt/#{@idclub}/#{@round}"}}"}
              class="underline"
            >
              aan met je KBSB-login
            </.link>.
          </p>
        <% :forbidden -> %>
          <p id="forbidden" class="rounded-lg bg-error/15 px-4 py-3 text-error">
            Je hebt geen beheerrechten voor club {@idclub}.
          </p>
        <% :ok -> %>
          <.page_header kicker={"Mgmt · ronde #{@round}"} title={@club["name"]}>
            <:subtitle>
              {length(@teams)} ploegen · {if @open,
                do: "ronde is open",
                else: "ronde nog niet begonnen"}
            </:subtitle>
            <:actions>
              <.btn href={~p"/print/#{@idclub}/#{@round}"}>{t("Fiches / ZIP")}</.btn>
              <.btn :if={@round > 1} href={~p"/mgmt/#{@idclub}/#{@round - 1}"}>
                ← R{@round - 1}
              </.btn>
              <.btn href={~p"/mgmt/#{@idclub}/#{@round + 1}"}>R{@round + 1} →</.btn>
            </:actions>
          </.page_header>

          <p
            :if={!@open and Enum.any?(@teams, &(ClubAdmin.filled(&1) < &1.nrgames))}
            id="missing-lineups"
            class="mb-4 rounded-lg bg-warning/20 px-4 py-2 text-sm"
          >
            Nog onvolledige opstelling: {@teams
            |> Enum.filter(&(ClubAdmin.filled(&1) < &1.nrgames))
            |> Enum.map_join(", ", &"#{&1.name} (#{ClubAdmin.filled(&1)}/#{&1.nrgames})")}
          </p>

          <div :if={!@open} class="mb-6 flex flex-wrap items-center gap-3">
            <button
              id="validate"
              phx-click="validate"
              class="rounded-lg border border-base-300 px-4 py-2 font-medium transition hover:border-primary"
            >
              {t("Controleren")}
            </button>
            <button
              id="submit"
              phx-click="submit"
              data-confirm="Alle opstellingen van deze ronde indienen bij de KBSB?"
              class="rounded-lg bg-primary px-4 py-2 font-semibold text-primary-content transition hover:opacity-90"
            >
              {t("Indienen bij KBSB")}
            </button>
            <span :if={@errors == []} id="valid" class="text-sm text-success">{t(
              "✓ Geen fouten gevonden"
            )}</span>
            <span :if={@errors not in [nil, []]} class="text-sm text-error">{length(@errors)} fout(en)</span>
          </div>

          <div class="grid gap-5 lg:grid-cols-2">
            <.card :for={t <- @teams} id={"team-#{t.key}"}>
              <:title>
                <span class="flex flex-wrap items-baseline justify-between gap-2">
                  <span>
                    {t.name}
                    <span class="opacity-50">{if t.playinghome, do: "thuis tegen", else: "uit bij"}</span>
                    {t.opponent.name}
                  </span>
                  <span class="text-xs font-normal opacity-60">
                    {t("Reeks %{s}", s: "#{t.division}#{t.index}")} · {ClubAdmin.filled(t)}/{t.nrgames}
                  </span>
                </span>
              </:title>

              <ul :if={team_errors(@errors, t) != []} class="mb-3 space-y-1 text-sm text-error">
                <li :for={e <- team_errors(@errors, t)}>
                  <span :if={e["boardnr"]}>Bord {e["boardnr"]}: </span>{e["errormessage"]}
                </li>
              </ul>

              <table class="w-full text-sm">
                <tr :for={b <- 1..t.nrgames} class="border-t border-base-200 first:border-0">
                  <td class="w-6 py-1 opacity-50">{b}</td>
                  <td class={["py-1", board_error?(team_errors(@errors, t), b) && "text-error"]}>
                    <%= if @open do %>
                      {name(@names, Enum.at(t.lineup, b - 1))}
                    <% else %>
                      <form phx-change="set_player" id={"plan-#{t.key}-#{b}"}>
                        <input type="hidden" name="team" value={t.key} />
                        <input type="hidden" name="board" value={b} />
                        <select
                          name="idnumber"
                          class="w-full rounded border border-base-300 bg-base-100 px-1 py-0.5"
                        >
                          <option value="">—</option>
                          {Phoenix.HTML.Form.options_for_select(@options, Enum.at(t.lineup, b - 1))}
                        </select>
                      </form>
                    <% end %>
                  </td>
                  <td :if={@open} class="w-28 px-2">
                    <form phx-change="set_result" id={"result-#{t.key}-#{b}"}>
                      <input type="hidden" name="team" value={t.key} />
                      <input type="hidden" name="board" value={b} />
                      <select
                        name="result"
                        class="w-full rounded border border-base-300 bg-base-100 px-1 py-0.5"
                      >
                        {Phoenix.HTML.Form.options_for_select(
                          Enum.map(
                            ClubAdmin.result_options(),
                            &{if(&1 == "", do: "—", else: &1), &1}
                          ),
                          Enum.at(t.results, b - 1)
                        )}
                      </select>
                    </form>
                  </td>
                  <td :if={@open} class="text-right opacity-70">
                    {name(@names, Enum.at(t.opponent_lineup, b - 1))}
                  </td>
                </tr>
              </table>

              <p :for={{side, s} <- signatures(t)} class="mt-2 text-xs text-success">
                ✓ {t(
                  if side == :home,
                    do: "Bevestigd door thuiskapitein",
                    else: "Bevestigd door uitkapitein"
                )}
                {name(@names, s.idnumber)} ({s.idnumber}) · {format_ts(s.ts)}
              </p>

              <div :if={@open} class="mt-3 flex flex-wrap items-center justify-end gap-3">
                <label
                  :if={is_integer(@idnumber)}
                  class="flex cursor-pointer items-center gap-2 text-sm"
                >
                  <input
                    type="checkbox"
                    id={"confirm-#{t.key}"}
                    phx-click="toggle_confirm"
                    phx-value-team={t.key}
                    checked={MapSet.member?(@confirm, t.key)}
                    class="size-4"
                  />
                  {t("Bevestigen als kapitein")}
                </label>
                <button
                  id={"save-results-#{t.key}"}
                  phx-click="save_results"
                  phx-value-team={t.key}
                  data-confirm={"Uitslag van #{t.name} – #{t.opponent.name} opslaan bij de KBSB?"}
                  class="rounded-lg bg-primary px-3 py-1.5 text-sm font-semibold text-primary-content"
                >
                  {t("Uitslag opslaan")}
                </button>
              </div>
            </.card>
          </div>
          <p :if={@teams == []} class="opacity-60">Geen ploegen van deze club in ronde {@round}.</p>
      <% end %>
    </Layouts.app>
    """
  end

  defp signatures(team) do
    for side <- [:home, :visit], s = team.signatures[side], s, do: {side, s}
  end

  defp format_ts(nil), do: ""

  defp format_ts(ts) when is_binary(ts) do
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%d/%m %H:%M UTC")
      _ -> ts
    end
  end

  defp players(idclub) do
    case Kbsb.club(idclub) do
      {:ok, %{"players" => p}} when is_list(p) -> p
      _ -> []
    end
  end

  defp name(_names, nil), do: "—"
  defp name(names, id), do: Map.get(names, id, "##{id}")
end
