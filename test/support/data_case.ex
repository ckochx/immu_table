defmodule ImmuTableEx.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias ImmuTableEx.TestRepo

      import Ecto
      import Ecto.Query
      import ImmuTableEx.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(ImmuTableEx.TestRepo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
