defmodule ImmuTableEx.TestRepo do
  use Ecto.Repo,
    otp_app: :immu_table_ex,
    adapter: Ecto.Adapters.Postgres
end
