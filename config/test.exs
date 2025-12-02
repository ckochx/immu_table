import Config

config :immu_table_ex, ImmuTableEx.TestRepo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "immu_table_ex_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :immu_table_ex, ecto_repos: [ImmuTableEx.TestRepo]

config :logger, level: :warning
