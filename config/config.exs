import Config

config :immu_table, ecto_repos: [ImmuTable.TestRepo]

if config_env() == :test do
  import_config "test.exs"
end
