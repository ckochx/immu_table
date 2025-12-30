defmodule Mix.Tasks.Immutable.Gen.Context do
  @shortdoc "Generates an ImmuTable context with schema"

  @moduledoc """
  Generates an ImmuTable context module with its schema.

      $ mix immutable.gen.context Blog Post posts title:string body:text

  The first argument is the context module name, followed by the schema name,
  table name, and field definitions.

  This generator creates:
    * A context module with ImmuTable CRUD operations
    * A schema with `immutable_schema`
    * History and undelete functions

  ## Example

      $ mix immutable.gen.context Accounts User users name:string email:string

  This will generate:

    * `lib/my_app/accounts.ex` - The context module
    * `lib/my_app/accounts/user.ex` - The ImmuTable schema

  The context includes these functions:
    * `list_users/0` - List all current (non-deleted) records
    * `get_user!/1` - Get by entity_id or raise
    * `get_user/1` - Get by entity_id or nil
    * `create_user/1` - Create version 1
    * `update_user/2` - Create new version
    * `delete_user/1` - Create tombstone
    * `undelete_user/1` - Restore from tombstone
    * `get_user_history/1` - Get all versions
    * `change_user/2` - Return changeset
  """

  use Mix.Task

  alias Mix.Immutable.Generator
  alias Mix.Immutable.Templates

  @impl true
  def run(args) do
    {context, schema, table, fields} = parse_args!(args)

    Generator.validate_module!(context, "context")
    Generator.validate_module!(schema, "schema")
    Generator.validate_table!(table, "immutable.gen.context")

    parsed_fields = Generator.parse_fields(fields)
    field_names = Generator.field_names(parsed_fields)

    base_app = Generator.base_app()
    otp_app = Generator.otp_app()
    context_inflections = Generator.inflect(context)
    schema_inflections = Generator.inflect(schema)

    context_module = "#{base_app}.#{context}"
    schema_module = "#{base_app}.#{context}.#{schema}"

    context_path = "lib/#{otp_app}/#{context_inflections.path}.ex"
    schema_path = "lib/#{otp_app}/#{context_inflections.path}/#{schema_inflections.path}.ex"

    singular = schema_inflections.singular
    plural = schema_inflections.plural

    schema_binding = [
      app_module: base_app,
      schema_module: schema_module,
      table: table,
      fields: parsed_fields,
      field_names: field_names
    ]

    context_binding = [
      app_module: base_app,
      context_module: context_module,
      schema_module: schema_module,
      schema_alias: schema,
      singular: singular,
      plural: plural,
      field_names: field_names
    ]

    File.mkdir_p!(Path.dirname(context_path))
    File.mkdir_p!(Path.dirname(schema_path))

    schema_content = EEx.eval_string(Templates.schema_template(), schema_binding)
    Mix.Generator.create_file(schema_path, schema_content)

    context_content = EEx.eval_string(Templates.context_template(), context_binding)
    Mix.Generator.create_file(context_path, context_content)
  end

  defp parse_args!([]) do
    Mix.raise("""
    expected immutable.gen.context to receive the context, schema, and table name.

    For example:

        mix immutable.gen.context Blog Post posts title:string body:text
    """)
  end

  defp parse_args!([_context]) do
    Mix.raise("""
    expected immutable.gen.context to receive the context, schema, and table name.

    For example:

        mix immutable.gen.context Blog Post posts title:string body:text
    """)
  end

  defp parse_args!([_context, _schema]) do
    Mix.raise("""
    expected immutable.gen.context to receive the context, schema, and table name.

    For example:

        mix immutable.gen.context Blog Post posts title:string body:text
    """)
  end

  defp parse_args!([context, schema, table | fields]) do
    {context, schema, table, fields}
  end
end
