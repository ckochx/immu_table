defmodule ImmuTable.MixProject do
  use Mix.Project

  @version "0.5.0"
  @source_url "https://github.com/ckochx/immu_table"

  def project do
    [
      app: :immu_table,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      elixirc_options: [warnings_as_errors: true],
      description: description(),
      package: package(),
      docs: docs(),
      name: "ImmuTable",
      source_url: @source_url
    ]
  end

  defp description do
    "Append-only (immutable) tables with version tracking for Ecto."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      check: ["format", "compile --force --warnings-as-errors"],
      "ecto.reset": ["ecto.drop", "ecto.create", "ecto.migrate"]
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
      {:uuidv7, "~> 0.2 or ~> 1.0"},
      {:postgrex, "~> 0.16", only: [:dev, :test]},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end
end
