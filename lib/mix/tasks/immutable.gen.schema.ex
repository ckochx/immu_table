defmodule Mix.Tasks.Immutable.Gen.Schema do
  @shortdoc "Generates an ImmuTable schema"

  @moduledoc """
  Generates an ImmuTable schema.

      $ mix immutable.gen.schema Blog.Post posts title:string body:text

  The first argument is the schema module name followed by the table name
  and a list of field definitions.

  ## Field types

  The generator supports the following field types:

    * `:string` - String type
    * `:text` - Text (long string) type
    * `:integer` - Integer type
    * `:float` - Float type
    * `:decimal` - Decimal type
    * `:boolean` - Boolean type
    * `:date` - Date type
    * `:time` - Time type
    * `:utc_datetime` - UTC DateTime type
    * `:utc_datetime_usec` - UTC DateTime with microseconds
    * `:uuid` - UUID type
    * `:binary` - Binary type
    * `:map` - Map/JSON type
    * `references` - Foreign key reference (e.g., `user_id:references:users`)

  ## Example

      $ mix immutable.gen.schema Accounts.User users name:string email:string age:integer

  This will generate:

    * `lib/my_app/accounts/user.ex` - The ImmuTable schema
  """

  use Mix.Task

  alias Mix.Immutable.Generator
  alias Mix.Immutable.Templates

  @impl true
  def run(args) do
    {schema, table, fields} = parse_args!(args)

    Generator.validate_module!(schema, "schema")
    Generator.validate_table!(table, "immutable.gen.schema")

    parsed_fields = Generator.parse_fields(fields)
    field_names = Generator.field_names(parsed_fields)

    base_app = Generator.base_app()
    inflections = Generator.inflect(schema)

    schema_module = "#{base_app}.#{schema}"
    schema_path = "lib/#{Generator.otp_app()}/#{inflections.path}.ex"

    binding = [
      app_module: base_app,
      schema_module: schema_module,
      table: table,
      fields: parsed_fields,
      field_names: field_names
    ]

    File.mkdir_p!(Path.dirname(schema_path))

    content = EEx.eval_string(Templates.schema_template(), binding)
    Mix.Generator.create_file(schema_path, content)
  end

  defp parse_args!([]) do
    Mix.raise("""
    expected immutable.gen.schema to receive the schema module name and table name.

    For example:

        mix immutable.gen.schema Blog.Post posts title:string body:text
    """)
  end

  defp parse_args!([_schema]) do
    Mix.raise("""
    expected immutable.gen.schema to receive the schema module name and table name.

    For example:

        mix immutable.gen.schema Blog.Post posts title:string body:text
    """)
  end

  defp parse_args!([schema, table | fields]) do
    {schema, table, fields}
  end
end
