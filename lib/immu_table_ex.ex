defmodule ImmuTableEx do
  @moduledoc """
  ImmuTableEx provides immutable table functionality for Ecto schemas.

  Instead of updating or deleting rows, new rows are inserted with version
  tracking metadata. This provides a complete audit trail and enables
  point-in-time queries.
  """

  defmacro __using__(opts) do
    quote do
      import ImmuTableEx.Schema

      @immutable_opts unquote(opts)
      @before_compile ImmuTableEx.Schema
    end
  end
end
