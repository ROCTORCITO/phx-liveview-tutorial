defmodule LiveviewLab.Repo do
  use Ecto.Repo,
    otp_app: :liveview_lab,
    adapter: Ecto.Adapters.SQLite3
end
