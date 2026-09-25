defmodule OpenInterclubsWeb.DivisionLive do
  use OpenInterclubsWeb.SeasonLive

  @impl true
  def mount(_params, _session, socket), do: {:ok, subscribe(socket)}

  @impl true
  def handle_params(%{"series" => slug} = params, _uri, socket) do
    key = parse_series(slug)

    round =
      case Integer.parse(params["round"] || "") do
        {n, ""} -> n
        _ -> Season.current_round()
      end

    {:noreply,
     socket
     |> assign(
       key: key,
       round: round,
       tab: params["tab"] || "stand",
       page_title: "Afdeling #{slug}"
     )
     |> refreshed()}
  end

  defp refresh(socket) do
    s = Season.series(socket.assigns.key)

    cross =
      if s do
        for r <- s.rounds, e <- r.encounters, into: %{} do
          {{e.home, e.visit}, e}
        end
      else
        %{}
      end

    assign(socket, s: s, cross: cross)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.loading :if={!@loaded?} />
      <p :if={@loaded? and is_nil(@s)}>Deze afdeling bestaat niet.</p>
      <div :if={@s}>
        <.page_header kicker={division_name(@s.division)} title={"Reeks #{@s.label}"}>
          <:subtitle>{length(@s.teams)} ploegen · {length(@s.rounds)} rondes</:subtitle>
        </.page_header>

        <.tabs
          active={@tab}
          tabs={[
            {"stand", "Rangschikking", ~p"/divisions/#{@s.label}"},
            {"kruistabel", "Onderlinge resultaten", ~p"/divisions/#{@s.label}?tab=kruistabel"},
            {"rondes", "Per ronde", ~p"/divisions/#{@s.label}?tab=rondes&round=#{@round}"}
          ]}
        />

        <.card :if={@tab == "stand"} id="standings">
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead class="text-left text-xs uppercase opacity-60">
                <tr>
                  <th class="py-2 pr-2">#</th>
                  <th class="py-2">Ploeg</th>
                  <th class="px-2 text-center" title="Gespeeld">Gesp.</th>
                  <th class="px-2 text-center" title="Gewonnen">W</th>
                  <th class="px-2 text-center" title="Gelijk">G</th>
                  <th class="px-2 text-center" title="Verloren">V</th>
                  <th class="px-2 text-right" title="Matchpunten">MP</th>
                  <th class="px-2 text-right" title="Bordpunten">BP</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={row <- @s.standings}
                  class="border-t border-base-200 transition hover:bg-base-200/60"
                >
                  <td class="py-2 pr-2 font-semibold opacity-60">{row.rank}</td>
                  <td class="py-2"><.team_link key={row.team} /></td>
                  <td class="px-2 text-center tabular-nums">{row.played}</td>
                  <td class="px-2 text-center tabular-nums">{row.won}</td>
                  <td class="px-2 text-center tabular-nums">{row.drawn}</td>
                  <td class="px-2 text-center tabular-nums">{row.lost}</td>
                  <td class="px-2 text-right text-base font-bold tabular-nums">{row.mp}</td>
                  <td class="px-2 text-right tabular-nums">{points(row.bp)}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </.card>

        <.card :if={@tab == "kruistabel"} id="crosstable">
          <div class="overflow-x-auto">
            <table class="text-sm">
              <thead>
                <tr>
                  <th></th>
                  <th
                    :for={{_, i} <- Enum.with_index(@s.standings, 1)}
                    class="w-12 px-1 text-center text-xs opacity-60"
                  >
                    {i}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={{row, i} <- Enum.with_index(@s.standings, 1)}
                  class="border-t border-base-200"
                >
                  <th class="whitespace-nowrap py-1.5 pr-3 text-left font-normal">
                    <span class="opacity-40">{i}.</span> <.team_link key={row.team} />
                  </th>
                  <td :for={col <- @s.standings} class="px-1 text-center">
                    <.cross_cell cross={@cross} a={row.team} b={col.team} />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <p class="mt-3 text-xs opacity-60">
            Rij = thuisploeg, kolom = uitploeg. Klik op een uitslag voor de borden.
          </p>
        </.card>

        <div :if={@tab == "rondes"}>
          <nav class="mb-4 flex flex-wrap gap-2">
            <.link
              :for={r <- @s.rounds}
              patch={~p"/divisions/#{@s.label}?tab=rondes&round=#{r.round}"}
              class={[
                "grid size-9 place-items-center rounded-lg text-sm font-semibold transition",
                if(r.round == @round,
                  do: "bg-primary text-primary-content",
                  else: "bg-base-200 hover:bg-base-300"
                )
              ]}
            >
              {r.round}
            </.link>
          </nav>
          <.card :for={r <- @s.rounds} :if={r.round == @round}>
            <:title>Ronde {r.round} · {date(r.date)}</:title>
            <.encounter_row :for={e <- r.encounters} e={e} />
          </.card>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :cross, :map, required: true
  attr :a, :any, required: true
  attr :b, :any, required: true

  defp cross_cell(assigns) do
    assigns = assign(assigns, :e, Map.get(assigns.cross, {assigns.a, assigns.b}))

    ~H"""
    <%= cond do %>
      <% @a == @b -> %>
        <span class="block h-7 rounded bg-base-300/60"></span>
      <% is_nil(@e) -> %>
        <span></span>
      <% @e.status == :planned -> %>
        <.link
          navigate={match_path(@e)}
          class="text-xs opacity-40 hover:opacity-100"
          title={date(@e.date)}
        >
          R{@e.round}
        </.link>
      <% true -> %>
        <.link navigate={match_path(@e)}><.score e={@e} for={:home} /></.link>
    <% end %>
    """
  end
end
