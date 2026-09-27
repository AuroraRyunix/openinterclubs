defmodule OpenInterclubsWeb.RedirectController do
  use OpenInterclubsWeb, :controller

  @doc "Old /beheer links (Clubbeheer is now Mgmt)."
  def beheer(conn, %{"idclub" => c, "round" => r}), do: redirect(conn, to: ~p"/mgmt/#{c}/#{r}")
  def beheer(conn, _), do: redirect(conn, to: ~p"/mgmt")
end
