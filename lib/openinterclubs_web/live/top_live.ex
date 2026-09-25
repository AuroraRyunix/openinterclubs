defmodule OpenInterclubsWeb.TopLive do
  use OpenInterclubsWeb.SeasonLive

  @per_page 25
  @sorts ~w(tpr diff score rating played)

  @impl true
  def mount(_params, _session, socket),
    do: {:ok, socket |> subscribe() |> assign(page_title: "Toplijst")}

  @impl true
  def handle_params(params, _uri, socket) do
    filters = %{
      "min" => int(params["min"], 3),
      "sort" => if(params["sort"] in @sorts, do: params["sort"], else: "tpr"),
      "q" => params["q"] || "",
      "page" => max(int(params["page"], 1), 1)
    }

    {:noreply, socket |> assign(filters: filters, form: to_form(filters, as: :f)) |> refreshed()}
  end

  @impl true
  def handle_event("filter", %{"f" => f}, socket) do
    params = socket.assigns.filters |> Map.merge(Map.take(f, ["min", "q"])) |> Map.put("page", 1)
    {:noreply, push_patch(socket, to: ~p"/top?#{params}")}
  end

  defp int(v, default) do
    case Integer.parse(to_string(v || "")) do
      {n, _} -> n
      _ -> default
    end
  end

  defp refresh(socket) do
    %{"min" => min, "sort" => sort, "q" => q, "page" => page} = socket.assigns.filters
    q = String.downcase(String.trim(q))
    field = String.to_existing_atom(sort)

    all =
      Season.players()
      |> Enum.filter(&(&1.played >= min))
      |> Enum.filter(&(q == "" or String.contains?(String.downcase(&1.name), q)))
      |> Enum.sort_by(&{Map.get(&1, field) || -9999, &1.rating}, :desc)

    assign(socket,
      total: length(all),
      pages: max(ceil(length(all) / @per_page), 1),
      rows: all |> Enum.drop((page - 1) * @per_page) |> Enum.take(@per_page),
      offset: (page - 1) * @per_page
    )
  end

  defp link_params(filters, changes), do: Map.merge(filters, changes)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.page_header kicker="Seizoen" title="Toplijst">
        <:subtitle>Beste prestaties (TPR zonder forfaits) · {@total} spelers</:subtitle>
      </.page_header>

      <.form
        for={@form}
        id="top-filter"
        phx-change="filter"
        class="mb-6 flex flex-wrap items-end gap-4"
      >
        <div class="w-40">
          <.input field={@form[:min]} type="number" min="0" label="Min. partijen" />
        </div>
        <div class="w-72">
          <.input field={@form[:q]} type="search" label="Naam" phx-debounce="200" />
        </div>
        <div class="flex gap-1 pb-2 text-sm">
          <span class="mr-1 self-center opacity-60">Sorteer:</span>
          <.link
            :for={
              {s, l} <- [
                {"tpr", "TPR"},
                {"diff", "+/−"},
                {"score", "Score"},
                {"rating", "Rating"},
                {"played", "Partijen"}
              ]
            }
            patch={~p"/top?#{link_params(@filters, %{"sort" => s, "page" => 1})}"}
            class={[
              "rounded-lg px-3 py-1",
              if(@filters["sort"] == s, do: "bg-primary text-primary-content", else: "bg-base-200")
            ]}
          >
            {l}
          </.link>
        </div>
      </.form>

      <.loading :if={!@loaded?} />
      <.card :if={@loaded?} id="ranking">
        <p :if={@rows == []} class="opacity-60">
          Nog geen spelers met {@filters["min"]} of meer partijen.
        </p>
        <.player_table :if={@rows != []} players={@rows} show_club offset={@offset} />
        <nav :if={@pages > 1} class="mt-4 flex items-center justify-between text-sm">
          <.link
            :if={@filters["page"] > 1}
            patch={~p"/top?#{link_params(@filters, %{"page" => @filters["page"] - 1})}"}
            class="rounded-lg bg-base-200 px-3 py-1"
          >
            ← Vorige
          </.link>
          <span class="opacity-60">Pagina {@filters["page"]} / {@pages}</span>
          <.link
            :if={@filters["page"] < @pages}
            patch={~p"/top?#{link_params(@filters, %{"page" => @filters["page"] + 1})}"}
            class="rounded-lg bg-base-200 px-3 py-1"
          >
            Volgende →
          </.link>
        </nav>
      </.card>
    </Layouts.app>
    """
  end
end
