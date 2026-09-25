defmodule OpenInterclubsWeb.MatchLive do
  use OpenInterclubsWeb.SeasonLive

  @impl true
  def mount(_params, _session, socket), do: {:ok, subscribe(socket)}

  @impl true
  def handle_params(%{"series" => slug, "round" => r, "club" => c, "team" => n}, _uri, socket) do
    key = {parse_series(slug), String.to_integer(r), {String.to_integer(c), String.to_integer(n)}}
    {:noreply, socket |> assign(key: key) |> refreshed()}
  end

  defp refresh(socket) do
    {series, round, home} = socket.assigns.key
    e = Season.encounter(series, round, home)

    assign(socket,
      e: e,
      page_title: e && "#{team_name(e.home)} – #{team_name(e.visit)}"
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.loading :if={!@loaded?} />
      <p :if={@loaded? and is_nil(@e)}>Deze ontmoeting bestaat niet.</p>
      <div :if={@e}>
        <p class="mb-2 text-sm opacity-60">
          <.link navigate={series_path(@e.series)} class="hover:text-primary">Reeks {series_slug(
            @e.series
          )}</.link>
          ·
          <.link navigate={~p"/rounds/#{@e.round}"} class="hover:text-primary">Ronde {@e.round}</.link>
          · {date(@e.date)}
        </p>
        <div class="mb-8 grid grid-cols-[1fr_auto_1fr] items-center gap-4 rounded-3xl bg-base-200 px-6 py-8">
          <div class="text-right">
            <.team_link key={@e.home} class="text-xl font-bold sm:text-2xl" />
            <p class="text-xs uppercase opacity-50">Thuis</p>
          </div>
          <div class="text-3xl font-extrabold tabular-nums sm:text-4xl">
            <%= if @e.status == :planned do %>
              <span class="opacity-40">vs</span>
            <% else %>
              {points(@e.bp_home)} – {points(@e.bp_visit)}
            <% end %>
            <p
              :if={@e.status == :live}
              class="text-center text-xs font-semibold uppercase text-warning"
            >
              live
            </p>
          </div>
          <div>
            <.team_link key={@e.visit} class="text-xl font-bold sm:text-2xl" />
            <p class="text-xs uppercase opacity-50">Uit</p>
          </div>
        </div>

        <div class="mb-4 flex justify-end">
          <.btn href={fiche_path(@e)} id="to-fiche">
            <.icon name="hero-printer" class="size-4" /> Uitslagenfiche
          </.btn>
        </div>

        <.card id="boards">
          <p :if={@e.games == []} class="opacity-60">Nog geen opstellingen ingediend.</p>
          <table :if={@e.games != []} class="w-full text-sm">
            <tbody>
              <tr :for={g <- @e.games} class="border-t border-base-200 first:border-0">
                <td class="w-8 py-2.5 font-semibold opacity-50">{g.board}</td>
                <td class="text-right">
                  <.player_link id={g.home} />
                  <span class="ml-1 text-xs tabular-nums opacity-50">{player_rating(g.home)}</span>
                </td>
                <td class="w-8 text-center">
                  <.color_dot color={if g.white == :home, do: :white, else: :black} />
                </td>
                <td class="w-20 text-center font-bold tabular-nums">
                  {OpenInterclubs.Season.Result.display(g.result)}
                </td>
                <td class="w-8 text-center">
                  <.color_dot color={if g.white == :visit, do: :white, else: :black} />
                </td>
                <td>
                  <.player_link id={g.visit} />
                  <span class="ml-1 text-xs tabular-nums opacity-50">{player_rating(g.visit)}</span>
                </td>
              </tr>
            </tbody>
          </table>
        </.card>
      </div>
    </Layouts.app>
    """
  end

  defp player_rating(nil), do: ""

  defp player_rating(id) do
    case Season.player(id) do
      %{rating: r} -> rating(r)
      _ -> ""
    end
  end
end
