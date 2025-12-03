defmodule ImmuTable.MixProject do
  use Mix.Project

  def project do
    [
      app: :immu_table,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      elixirc_options: [warnings_as_errors: true]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      check: ["format", "compile --force --warnings-as-errors"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ImmuTable.Application, []}
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:uuidv7, "~> 0.2"},
      {:postgrex, "~> 0.17", only: [:dev, :test]}
    ]
  end
end
