import Config

config :immu_table, ImmuTable.TestRepo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "immu_table_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :immu_table, ecto_repos: [ImmuTable.TestRepo]

config :logger, level: :warning
