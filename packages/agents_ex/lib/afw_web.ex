defmodule AFWWeb do
  @moduledoc false

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json], layouts: []
      import Plug.Conn
      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView, layout: {AFWWeb.Layouts, :app}
      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent
      unquote(html_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Phoenix.LiveView.Router
    end
  end

  def html do
    quote do
      use Phoenix.Component
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.Component
      import Phoenix.LiveView.Helpers
      alias Phoenix.LiveView.JS
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: AFWWeb.Endpoint,
        router: AFWWeb.Router,
        statics: AFWWeb.static_paths()
    end
  end

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
