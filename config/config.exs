import Config

config :immu_table_ex, ecto_repos: [ImmuTableEx.TestRepo]

if config_env() == :test do
  import_config "test.exs"
end
