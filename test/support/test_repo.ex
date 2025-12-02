defmodule ImmuTable.TestRepo do
  use Ecto.Repo,
    otp_app: :immu_table,
    adapter: Ecto.Adapters.Postgres
end
