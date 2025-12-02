defmodule ImmuTable.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = children(Mix.env())

    opts = [strategy: :one_for_one, name: ImmuTable.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp children(:test) do
    [ImmuTable.TestRepo]
  end

  defp children(_env) do
    []
  end
end
