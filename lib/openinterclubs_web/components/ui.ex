defmodule OpenInterclubsWeb.UI do
  @moduledoc "Hand-rolled Tailwind components for the season pages."
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: OpenInterclubsWeb.Endpoint,
    router: OpenInterclubsWeb.Router

  import OpenInterclubsWeb.Fmt

  attr :title, :string, required: true
  attr :kicker, :string, default: nil
  slot :subtitle
  slot :actions

  def page_header(assigns) do
    ~H"""
    <div class="mb-8 flex flex-wrap items-end justify-between gap-4">
      <div>
        <p :if={@kicker} class="text-xs font-semibold uppercase tracking-widest text-primary">
          {@kicker}
        </p>
        <h1 class="text-3xl font-bold tracking-tight">{@title}</h1>
        <p :if={@subtitle != []} class="mt-1 text-sm opacity-70">{render_slot(@subtitle)}</p>
      </div>
      <div :if={@actions != []} class="flex flex-wrap gap-2">{render_slot(@actions)}</div>
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true
  slot :title

  def card(assigns) do
    ~H"""
    <section
      class={[
        "rounded-2xl border border-base-300 bg-base-100 shadow-sm transition-shadow hover:shadow-md",
        @class
      ]}
      {@rest}
    >
      <h2 :if={@title != []} class="border-b border-base-300 px-5 py-3 text-sm font-semibold">
        {render_slot(@title)}
      </h2>
      <div class="p-5">{render_slot(@inner_block)}</div>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :hint, :string, default: nil

  def stat(assigns) do
    ~H"""
    <div class="rounded-xl bg-base-200 px-4 py-3">
      <div class="text-xs uppercase tracking-wide opacity-60">{@label}</div>
      <div class="text-2xl font-bold tabular-nums">{@value}</div>
      <div :if={@hint} class="text-xs opacity-60">{@hint}</div>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def btn(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class={[
        "inline-flex items-center gap-1.5 rounded-lg border border-base-300 bg-base-100 px-3 py-1.5",
        "text-sm font-medium transition hover:-translate-y-px hover:border-primary hover:text-primary",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :tabs, :list, required: true, doc: "list of {id, label, href}"
  attr :active, :string, required: true

  def tabs(assigns) do
    ~H"""
    <nav class="mb-6 flex gap-1 overflow-x-auto rounded-xl bg-base-200 p-1">
      <.link
        :for={{id, label, href} <- @tabs}
        patch={href}
        class={[
          "whitespace-nowrap rounded-lg px-4 py-1.5 text-sm font-medium transition",
          if(id == @active,
            do: "bg-base-100 shadow-sm",
            else: "opacity-70 hover:opacity-100"
          )
        ]}
      >
        {label}
      </.link>
    </nav>
    """
  end

  @doc "Match score pill; colour relative to `for` (:home/:visit) when given."
  attr :e, :map, required: true
  attr :for, :atom, default: nil

  def score(assigns) do
    ~H"""
    <span class={[
      "inline-flex min-w-16 justify-center rounded-md px-2 py-0.5 font-semibold tabular-nums",
      score_class(@e, @for)
    ]}>
      <%= if @e.status == :planned do %>
        –
      <% else %>
        {points(@e.bp_home)} – {points(@e.bp_visit)}
      <% end %>
    </span>
    """
  end

  defp score_class(%{status: :planned}, _), do: "bg-base-200 opacity-60"
  defp score_class(%{status: :live}, _), do: "bg-warning/20 text-warning-content animate-pulse"
  defp score_class(_, nil), do: "bg-base-200"

  defp score_class(e, side) do
    mine = if side == :home, do: e.mp_home, else: e.mp_visit

    case mine do
      2 -> "bg-success/20 text-success"
      1 -> "bg-base-300"
      _ -> "bg-error/15 text-error"
    end
  end

  attr :result, :any, required: true
  attr :label, :string, required: true

  def game_result(assigns) do
    ~H"""
    <span class={[
      "inline-flex w-9 justify-center rounded px-1 text-sm font-bold",
      case @label do
        "1" <> _ -> "bg-success/20 text-success"
        "½" -> "bg-base-300"
        "0" <> _ -> "bg-error/15 text-error"
        _ -> "opacity-40"
      end
    ]}>
      {if @label == "", do: "·", else: @label}
    </span>
    """
  end

  attr :color, :atom, required: true

  def color_dot(assigns) do
    ~H"""
    <span
      title={if @color == :white, do: "Wit", else: "Zwart"}
      class={[
        "inline-block size-3 rounded-full border border-base-content/40",
        if(@color == :white, do: "bg-white", else: "bg-neutral-900")
      ]}
    />
    """
  end

  attr :key, :any, required: true
  attr :class, :any, default: nil

  def team_link(assigns) do
    ~H"""
    <.link navigate={team_path(@key)} class={["hover:text-primary hover:underline", @class]}>
      {team_name(@key)}
    </.link>
    """
  end

  attr :id, :any, required: true
  attr :class, :any, default: nil

  def player_link(assigns) do
    ~H"""
    <%= if @id do %>
      <.link navigate={player_path(@id)} class={["hover:text-primary hover:underline", @class]}>
        {player_name(@id)}
      </.link>
    <% else %>
      <span class="opacity-40">—</span>
    <% end %>
    """
  end

  def loading(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center gap-3 py-24 opacity-70">
      <span class="size-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
      <p>Seizoensgegevens worden geladen van de KBSB…</p>
    </div>
    """
  end

  @doc "One encounter as a compact row."
  attr :e, :map, required: true
  attr :highlight, :any, default: nil

  def encounter_row(assigns) do
    ~H"""
    <.link
      navigate={match_path(@e)}
      class="grid grid-cols-[1fr_auto_1fr] items-center gap-3 rounded-lg px-3 py-2 transition hover:bg-base-200"
    >
      <span class={["truncate text-right", @highlight == @e.home && "font-semibold"]}>
        {team_name(@e.home)}
      </span>
      <.score e={@e} />
      <span class={["truncate", @highlight == @e.visit && "font-semibold"]}>
        {team_name(@e.visit)}
      </span>
    </.link>
    """
  end

  attr :players, :list, required: true
  attr :show_club, :boolean, default: false
  attr :offset, :integer, default: 0

  def player_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead class="text-left text-xs uppercase opacity-60">
          <tr>
            <th :if={@offset > 0 or @show_club} class="py-2 pr-2">#</th>
            <th class="py-2">Speler</th>
            <th :if={@show_club} class="py-2">Club</th>
            <th class="px-2 text-right">Rating</th>
            <th class="px-2 text-right">FIDE</th>
            <th class="px-2 text-right">Score</th>
            <th class="px-2 text-right">TPR</th>
            <th class="px-2 text-right">+/−</th>
          </tr>
        </thead>
        <tbody>
          <tr
            :for={{p, i} <- Enum.with_index(@players, @offset + 1)}
            class="border-t border-base-200 transition hover:bg-base-200/60"
          >
            <td :if={@offset > 0 or @show_club} class="py-2 pr-2 opacity-50">{i}</td>
            <td class="py-2">
              <.player_link id={p.id} />
              <span :if={p.titular} class="ml-1 text-xs opacity-50">{p.titular}</span>
            </td>
            <td :if={@show_club} class="py-2">
              <.link navigate={club_path(p.club_id)} class="opacity-70 hover:text-primary">
                {OpenInterclubsWeb.Fmt.club_name(p.club_id)}
              </.link>
            </td>
            <td class="px-2 text-right tabular-nums">{rating(p.rating)}</td>
            <td class="px-2 text-right tabular-nums opacity-70">{rating(p.fide)}</td>
            <td class="px-2 text-right tabular-nums">
              <span :if={p.played > 0}>{points(p.score)}/{p.played}</span>
            </td>
            <td class="px-2 text-right font-semibold tabular-nums">{p.tpr}</td>
            <td class={[
              "px-2 text-right tabular-nums",
              p.diff && p.diff > 0 && "text-success",
              p.diff && p.diff < 0 && "text-error"
            ]}>
              {p.diff && if(p.diff > 0, do: "+#{p.diff}", else: p.diff)}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
