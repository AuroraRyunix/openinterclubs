defmodule OpenInterclubsWeb.SessionHTML do
  use OpenInterclubsWeb, :html

  def new(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-sm">
        <h1 class="mb-2 text-2xl font-bold">Aanmelden bij de KBSB</h1>

        <div :if={@user} class="mb-6 rounded-xl bg-base-200 p-4 text-sm">
          Aangemeld als <b>{@user}</b>.
          <.form for={%{}} action={~p"/logout"} method="post" class="mt-2">
            <button id="logout" class="underline">Afmelden</button>
          </.form>
        </div>

        <p class="mb-6 text-sm opacity-70">
          Met je KBSB-login kan de uitslagenfiche de opstelling van je eigen club invullen.
          Je wachtwoord wordt enkel doorgegeven aan de KBSB en niet bewaard; de sessie vervalt na 12 uur.
        </p>

        <p
          :if={@error}
          id="login-error"
          class="mb-4 rounded-lg bg-error/15 px-3 py-2 text-sm text-error"
        >
          {@error}
        </p>

        <.form for={%{}} action={~p"/login"} method="post" id="login-form" class="space-y-4">
          <input type="hidden" name="return_to" value={@return_to} />
          <.input name="user" value="" label="Lidnummer of e-mail" autocomplete="username" required />
          <.input
            name="password"
            value=""
            type="password"
            label="Wachtwoord"
            autocomplete="current-password"
            required
          />
          <button class="w-full rounded-lg bg-primary px-4 py-2 font-semibold text-primary-content transition hover:opacity-90">
            Aanmelden
          </button>
        </.form>
      </div>
    </Layouts.app>
    """
  end
end
