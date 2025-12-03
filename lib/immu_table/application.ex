defmodule ImmuTable.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Don't start any children when used as a dependency.
    # The test repo is only available when running immu_table's own tests.
    children =
      if Code.ensure_loaded?(ImmuTable.TestRepo) do
        [ImmuTable.TestRepo]
      else
        []
      end

    opts = [strategy: :one_for_one, name: ImmuTable.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
