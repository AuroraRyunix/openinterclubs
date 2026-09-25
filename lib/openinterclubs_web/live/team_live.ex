defmodule OpenInterclubsWeb.TeamLive do
  use OpenInterclubsWeb.SeasonLive

  @impl true
  def mount(_params, _session, socket), do: {:ok, subscribe(socket)}

  @impl true
  def handle_params(%{"id" => c, "number" => n} = params, _uri, socket) do
    key = {String.to_integer(c), String.to_integer(n)}

    board =
      case Integer.parse(params["board"] || "") do
        {b, ""} -> b
        _ -> nil
      end

    {:noreply,
     socket |> assign(key: key, tab: params["tab"] || "uitslagen", board: board) |> refreshed()}
  end

  defp refresh(socket) do
    key = socket.assigns.key
    team = Season.team(key)
    encounters = Season.team_encounters(key)
    s = team && Season.series(team.series)

    # Every player who played for this team, with their games for it.
    games =
      for e <- encounters,
          g <- e.games,
          side <- [:home, :visit],
          Map.fetch!(e, side) == key,
          id = Map.get(g, side),
          id do
        {id, g.board}
      end

    lineup =
      games
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(fn {id, boards} ->
        p = Season.player(id)
        own = if p, do: Enum.filter(p.games, &(&1.team == key and &1.score != nil)), else: []

        %{
          id: id,
          player: p,
          boards: Enum.frequencies(boards),
          games: length(own),
          score: own |> Enum.map(& &1.score) |> Enum.sum()
        }
      end)
      |> Enum.sort_by(&(-((&1.player && &1.player.rating) || 0)))

    assign(socket,
      team: team,
      series: s,
      row: s && Enum.find(s.standings, &(&1.team == key)),
      encounters: encounters,
      lineup: lineup,
      boards: if(team, do: OpenInterclubs.Season.Build.boards(team.division), else: 0),
      titulars:
        if(team,
          do:
            team.club_id
            |> Season.club()
            |> then(&Season.players((&1 && &1.players) || []))
            |> Enum.filter(&(&1.titular == team.name)),
          else: []
        ),
      page_title: team && team.name
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.loading :if={!@loaded?} />
      <p :if={@loaded? and is_nil(@team)}>Deze ploeg bestaat niet.</p>
      <div :if={@team}>
        <.page_header kicker={"Reeks #{series_slug(@team.series)}"} title={@team.name}>
          <:subtitle>
            <.link navigate={club_path(@team.club_id)} class="hover:text-primary">{@team.club_name}</.link>
          </:subtitle>
          <:actions>
            <.btn href={series_path(@team.series)}>Stand reeks</.btn>
          </:actions>
        </.page_header>

        <div :if={@row} class="mb-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
          <.stat label="Plaats" value={"#{@row.rank}/#{length(@series.teams)}"} />
          <.stat label="Matchpunten" value={@row.mp} />
          <.stat label="Bordpunten" value={points(@row.bp)} />
          <.stat label="W / R / V" value={"#{@row.won}/#{@row.drawn}/#{@row.lost}"} />
        </div>

        <.tabs
          active={@tab}
          tabs={[
            {"uitslagen", "Uitslagen", team_path(@team.key)},
            {"spelers", "Spelers", team_path(@team.key) <> "?tab=spelers"},
            {"rondes", "Rondes", team_path(@team.key) <> "?tab=rondes"}
          ]}
        />

        <.card :if={@tab == "uitslagen"} id="results">
          <div :for={e <- @encounters} class="grid grid-cols-[3rem_5rem_1fr] items-center gap-2">
            <span class="text-sm font-semibold opacity-50">R{e.round}</span>
            <span class="text-xs opacity-60">{short_date(e.date)}</span>
            <.encounter_row e={e} highlight={@team.key} />
          </div>
        </.card>

        <div :if={@tab == "spelers"} id="lineup">
          <nav class="mb-4 flex flex-wrap items-center gap-2 text-sm">
            <span class="opacity-60">Bord:</span>
            <.link
              patch={team_path(@team.key) <> "?tab=spelers"}
              class={[
                "rounded-lg px-3 py-1",
                if(is_nil(@board), do: "bg-primary text-primary-content", else: "bg-base-200")
              ]}
            >
              Alle
            </.link>
            <.link
              :for={b <- 1..@boards}
              patch={team_path(@team.key) <> "?tab=spelers&board=#{b}"}
              class={[
                "rounded-lg px-3 py-1",
                if(@board == b, do: "bg-primary text-primary-content", else: "bg-base-200")
              ]}
            >
              {b}
            </.link>
          </nav>
          <.card>
            <table class="w-full text-sm">
              <thead class="text-left text-xs uppercase opacity-60">
                <tr>
                  <th class="py-2">Speler</th>
                  <th class="px-2 text-right">Rating</th>
                  <th class="px-2">Borden</th>
                  <th class="px-2 text-right">Score</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={l <- @lineup}
                  :if={is_nil(@board) or Map.has_key?(l.boards, @board)}
                  class="border-t border-base-200"
                >
                  <td class="py-2"><.player_link id={l.id} /></td>
                  <td class="px-2 text-right tabular-nums">{l.player && rating(l.player.rating)}</td>
                  <td class="px-2 text-xs opacity-70">
                    {l.boards
                    |> Enum.sort()
                    |> Enum.map_join(", ", fn {b, n} -> if n > 1, do: "#{b} (#{n}×)", else: "#{b}" end)}
                  </td>
                  <td class="px-2 text-right tabular-nums">
                    <span :if={l.games > 0}>{points(l.score)}/{l.games}</span>
                  </td>
                </tr>
              </tbody>
            </table>
            <p :if={@lineup == []} class="opacity-60">Nog geen partijen gespeeld.</p>
          </.card>
          <.card :if={@titulars != []} class="mt-4">
            <:title>Titularissen</:title>
            <.player_table players={@titulars} />
          </.card>
        </div>

        <div :if={@tab == "rondes"} class="grid gap-4 md:grid-cols-2">
          <.card :for={e <- @encounters}>
            <:title>
              <.link navigate={match_path(e)} class="hover:text-primary">
                Ronde {e.round} · {team_name(e.home)} – {team_name(e.visit)}
              </.link>
            </:title>
            <p :if={e.games == []} class="text-sm opacity-60">Nog geen opstelling.</p>
            <table :if={e.games != []} class="w-full text-sm">
              <tr :for={g <- e.games} class="border-t border-base-200 first:border-0">
                <td class="w-6 py-1 opacity-50">{g.board}</td>
                <td class="text-right"><.player_link id={g.home} /></td>
                <td class="w-16 text-center font-bold">
                  {OpenInterclubs.Season.Result.display(g.result)}
                </td>
                <td><.player_link id={g.visit} /></td>
              </tr>
            </table>
          </.card>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
