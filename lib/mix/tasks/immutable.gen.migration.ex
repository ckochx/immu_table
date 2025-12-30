defmodule Mix.Tasks.Immutable.Gen.Migration do
  @shortdoc "Generates an ImmuTable migration"

  @moduledoc """
  Generates an ImmuTable migration.

      $ mix immutable.gen.migration Blog.Post posts title:string body:text

  The first argument is the schema module name followed by the table name
  and a list of field definitions.

  This generates a migration using `create_immutable_table` which automatically
  adds the ImmuTable metadata columns (id, entity_id, version, valid_from, deleted_at)
  and proper indexes.

  ## References

  Foreign keys in ImmuTable reference the `entity_id` column instead of `id`:

      $ mix immutable.gen.migration Blog.Comment comments body:text post_id:references:posts

  This generates:

      add :post_id, references(:posts, column: :entity_id, type: :uuid)

  ## Example

      $ mix immutable.gen.migration Accounts.User users name:string email:string

  This will generate:

    * `priv/repo/migrations/TIMESTAMP_create_users.exs` - The migration file
  """

  use Mix.Task

  alias Mix.Immutable.Generator
  alias Mix.Immutable.Templates

  @impl true
  def run(args) do
    {_schema, table, fields} = parse_args!(args)

    Generator.validate_table!(table, "immutable.gen.migration")

    parsed_fields = Generator.parse_fields(fields)

    base_app = Generator.base_app()
    migration_name = "Create#{Generator.camelize(table)}"
    timestamp = Generator.timestamp()
    migration_path = "priv/repo/migrations/#{timestamp}_create_#{table}.exs"

    binding = [
      app_module: base_app,
      migration_name: migration_name,
      table: table,
      fields: parsed_fields
    ]

    File.mkdir_p!(Path.dirname(migration_path))

    content = EEx.eval_string(Templates.migration_template(), binding)
    Mix.Generator.create_file(migration_path, content)
  end

  defp parse_args!([]) do
    Mix.raise("""
    expected immutable.gen.migration to receive the schema module name and table name.

    For example:

        mix immutable.gen.migration Blog.Post posts title:string body:text
    """)
  end

  defp parse_args!([_schema]) do
    Mix.raise("""
    expected immutable.gen.migration to receive the schema module name and table name.

    For example:

        mix immutable.gen.migration Blog.Post posts title:string body:text
    """)
  end

  defp parse_args!([schema, table | fields]) do
    {schema, table, fields}
  end
end
