defmodule OpenInterclubsWeb.PlayerLive do
  use OpenInterclubsWeb.SeasonLive

  @impl true
  def mount(_params, session, socket), do: {:ok, subscribe(socket, session)}

  @impl true
  def handle_params(%{"id" => id}, _uri, socket),
    do: {:noreply, socket |> assign(id: String.to_integer(id)) |> refreshed()}

  defp refresh(socket) do
    p = Season.player(socket.assigns.id)
    assign(socket, p: p, page_title: p && p.name)
  end

  defp signed(nil), do: "–"
  defp signed(n) when n > 0, do: "+#{format(n)}"
  defp signed(n), do: format(n)

  defp format(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 1)
  defp format(n), do: to_string(n)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} season={@season}>
      <.loading :if={!@loaded?} />
      <p :if={@loaded? and is_nil(@p)}>{t("Speler niet gevonden in de interclub-lijsten.")}</p>
      <div :if={@p}>
        <div class="mb-8 flex flex-wrap items-center gap-6 rounded-3xl bg-gradient-to-br from-primary/15 via-base-200 to-base-100 p-6 sm:p-8">
          <div class="grid size-20 place-items-center rounded-2xl bg-primary text-3xl font-extrabold text-primary-content shadow">
            {String.first(@p.first_name || "?")}{String.first(@p.last_name || "")}
          </div>
          <div class="flex-1">
            <p class="text-xs font-semibold uppercase tracking-widest text-primary">
              Stamnummer {@p.id}
            </p>
            <h1 class="text-3xl font-bold tracking-tight">{@p.name}</h1>
            <p class="mt-1 text-sm">
              <.link navigate={club_path(@p.club_id)} class="hover:text-primary">{club_name(
                @p.club_id
              )}</.link>
              <span :if={@p.titular} class="opacity-60">· {t("titularis")} {@p.titular}</span>
            </p>
          </div>
        </div>

        <div class="mb-8 grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-8">
          <.stat label={t("Interclub")} value={rating(@p.rating)} />
          <.stat label="FIDE" value={rating(@p.fide)} />
          <.stat label={t("Nationaal")} value={rating(@p.nat)} />
          <.stat label={t("Score")} value={"#{points(@p.score)}/#{@p.played}"} />
          <.stat label="TPR" value={@p.tpr || "–"} hint={"#{@p.rated_games} partijen zonder forfait"} />
          <.stat
            label="+/−"
            value={(@p.diff && if(@p.diff > 0, do: "+#{@p.diff}", else: @p.diff)) || "–"}
          />
          <.stat label="W − We" value={signed(@p[:w_we])} hint={t("score t.o.v. verwachting")} />
          <.stat label="FIDE ±" value={signed(@p[:fide_change])} hint={t("schatting (K 20/10)")} />
        </div>

        <.card id="games">
          <:title>{t("Partijen")}</:title>
          <p :if={@p.games == []} class="opacity-60">{t("Nog geen partijen dit seizoen.")}</p>
          <div :if={@p.games != []} class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead class="text-left text-xs uppercase opacity-60">
                <tr>
                  <th class="py-2">R</th>
                  <th>{t("Datum")}</th>
                  <th>{t("Bord")}</th>
                  <th></th>
                  <th>{t("Tegenstander")}</th>
                  <th class="text-right">{t("Rating")}</th>
                  <th class="px-2 text-center">{t("Verwacht")}</th>
                  <th class="px-2 text-center">{t("Uitslag")}</th>
                  <th>{t("Ontmoeting")}</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={g <- @p.games}
                  class="border-t border-base-200 transition hover:bg-base-200/60"
                >
                  <td class="py-2 font-semibold opacity-60">{g.round}</td>
                  <td class="whitespace-nowrap opacity-70">{short_date(g.date)}</td>
                  <td class="tabular-nums">{g.board}</td>
                  <td><.color_dot color={g.color} /></td>
                  <td><.player_link id={g.opponent} /></td>
                  <td class="text-right tabular-nums opacity-70">{rating(g.opponent_rating)}</td>
                  <td class="px-2 text-center tabular-nums opacity-70">
                    {g[:expected] && :erlang.float_to_binary(g.expected, decimals: 2)}
                  </td>
                  <td class="px-2 text-center"><.game_result result={g.result} label={g.label} /></td>
                  <td class="text-xs">
                    <.team_link key={g.team} /> <span class="opacity-40">vs</span>
                    <.team_link key={g.opp_team} />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </.card>
      </div>
    </Layouts.app>
    """
  end
end
