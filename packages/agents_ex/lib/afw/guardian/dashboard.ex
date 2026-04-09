defmodule AFW.Guardian.Dashboard do
  @moduledoc "Writes Guardian analytics JSON for LiveView and external tooling."

  def write(payload) do
    path = Application.fetch_env!(:afw, :guardian_dashboard_path)
    resolved = Path.expand(path, File.cwd!())
    File.mkdir_p!(Path.dirname(resolved))
    File.write!(resolved, Jason.encode_to_iodata!(payload, pretty: true))
    Phoenix.PubSub.broadcast(AFW.PubSub, "guardian", {:guardian_dashboard, payload})
    resolved
  end
end
