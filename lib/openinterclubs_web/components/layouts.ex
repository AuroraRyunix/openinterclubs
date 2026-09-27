defmodule OpenInterclubsWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use OpenInterclubsWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :season, :string, default: nil, doc: "archived season being viewed, if any"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="screen-only sticky top-0 z-30 border-b border-base-300 bg-base-100/85 backdrop-blur">
      <div class="mx-auto flex max-w-6xl flex-wrap items-center gap-x-4 gap-y-1 px-4 py-2 sm:px-6 md:flex-nowrap md:py-3">
        <a href="/" class="order-1 flex items-center gap-2 font-bold tracking-tight">
          <img src={~p"/images/logo-mark.svg"} alt="" class="size-7" />
          <span>OpenInterclubs</span>
        </a>
        <nav class="order-3 -mx-2 flex w-full gap-1 overflow-x-auto text-sm md:order-2 md:mx-0 md:w-auto md:flex-1">
          <.nav_link href={~p"/rounds"}>{t("Uitslagen")}</.nav_link>
          <.nav_link href={~p"/divisions"}>{t("Afdelingen")}</.nav_link>
          <.nav_link href={~p"/top"}>{t("Spelers")}</.nav_link>
          <.nav_link href={~p"/fiche"}>{t("Uitslagenfiche")}</.nav_link>
          <.nav_link :if={OpenInterclubsWeb.Locale.current_user()} href={~p"/beheer"}>
            {t("Clubbeheer")}
          </.nav_link>
        </nav>
        <div class="order-2 ml-auto flex items-center gap-3 md:order-3">
          <a
            href={~p"/login"}
            title={OpenInterclubsWeb.Locale.current_user() || t("KBSB-login")}
            class="flex items-center gap-1 whitespace-nowrap text-sm opacity-75 hover:opacity-100"
          >
            <.icon name="hero-user-circle" class="size-5" />
            <span class="hidden sm:inline">
              {if OpenInterclubsWeb.Locale.current_user(), do: t("Afmelden"), else: t("KBSB-login")}
            </span>
          </a>
          <nav id="lang-switch" class="flex gap-0.5 text-xs font-semibold">
            <a
              :for={l <- OpenInterclubsWeb.I18n.locales()}
              href={"/taal?lang=#{l}"}
              class={[
                "rounded px-1.5 py-1 uppercase",
                if(l == OpenInterclubsWeb.I18n.locale(),
                  do: "bg-base-300",
                  else: "opacity-60 hover:opacity-100"
                )
              ]}
            >
              {l}
            </a>
          </nav>
          <div class="hidden sm:block"><.theme_toggle /></div>
        </div>
      </div>
    </header>

    <div
      :if={@season}
      id="season-banner"
      class="screen-only bg-warning/20 px-4 py-2 text-center text-sm"
    >
      Je bekijkt seizoen <b>{OpenInterclubs.Season.Archive.label(@season)}</b>.
      <a href={~p"/seizoen?season=current"} class="underline">{t("Terug naar dit seizoen")}</a>
    </div>

    <main class="px-4 py-8 sm:px-6 print:p-0">
      <div class="mx-auto max-w-6xl">
        {render_slot(@inner_block)}
      </div>
    </main>

    <footer class="screen-only mx-auto max-w-6xl px-4 pb-10 pt-4 text-xs opacity-60 sm:px-6">
      <a class="underline" href="https://github.com/AuroraRyunix/openinterclubs">
        github.com/AuroraRyunix/openinterclubs
      </a>
    </footer>

    <.flash_group flash={@flash} />
    """
  end

  attr :href, :string, required: true
  slot :inner_block, required: true

  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class="whitespace-nowrap rounded-lg px-3 py-1.5 font-medium opacity-75 transition hover:bg-base-200 hover:opacity-100"
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
