defmodule Mix.Immutable.Generator do
  @moduledoc false

  @type_map %{
    "string" => :string,
    "text" => :text,
    "integer" => :integer,
    "float" => :float,
    "decimal" => :decimal,
    "boolean" => :boolean,
    "date" => :date,
    "time" => :time,
    "utc_datetime" => :utc_datetime,
    "utc_datetime_usec" => :utc_datetime_usec,
    "naive_datetime" => :naive_datetime,
    "naive_datetime_usec" => :naive_datetime_usec,
    "uuid" => :uuid,
    "binary" => :binary,
    "map" => :map,
    "array" => :array
  }

  def inflect(singular) do
    base = underscore(singular)
    module = camelize(singular)
    scoped = camelize(base)
    path = String.replace(base, ".", "/")
    human = humanize(singular)
    plural = pluralize(base)

    %{
      singular: base,
      plural: plural,
      module: module,
      scoped: scoped,
      path: path,
      human: human
    }
  end

  def base_app do
    Mix.Project.config()[:app] |> to_string() |> camelize()
  end

  def otp_app do
    Mix.Project.config()[:app]
  end

  def validate_module!(name, task_name) do
    unless valid_module?(name) do
      Mix.raise(
        "expected the #{task_name} argument, #{inspect(name)}, to be a valid module name"
      )
    end
  end

  def validate_table!(table, _task_name) do
    unless valid_table?(table) do
      Mix.raise(
        "expected the table name, #{inspect(table)}, to be lowercase with underscores. " <>
          "Received: #{inspect(table)}"
      )
    end
  end

  def parse_fields(fields) do
    Enum.map(fields, &parse_field/1)
  end

  def parse_field(field) do
    case String.split(field, ":") do
      [name] ->
        {String.to_atom(name), :string, nil}

      [name, "references", table] ->
        {String.to_atom(name), :references, table}

      [name, type] ->
        ecto_type = Map.get(@type_map, type, String.to_atom(type))
        {String.to_atom(name), ecto_type, nil}

      [name, type, _extra] ->
        ecto_type = Map.get(@type_map, type, String.to_atom(type))
        {String.to_atom(name), ecto_type, nil}
    end
  end

  def field_names(fields) do
    Enum.map(fields, fn {name, _type, _ref} -> name end)
  end

  def schema_type(type, _ref) when type in [:references], do: "Ecto.UUID"
  def schema_type(:text, _), do: ":string"
  def schema_type(type, _), do: inspect(type)

  def migration_type(:references, table), do: "references(:#{table}, column: :entity_id, type: :uuid)"
  def migration_type(type, _), do: inspect(type)

  def copy_from(source_dir, binding, files) do
    for {format, source_file, target_path} <- files do
      source = Path.join(source_dir, source_file)
      content = EEx.eval_file(source, binding)

      case format do
        :eex ->
          Mix.Generator.create_file(target_path, content)

        :new_eex ->
          if File.exists?(target_path) do
            :ok
          else
            Mix.Generator.create_file(target_path, content)
          end
      end
    end
  end

  def template_dir do
    Application.app_dir(:immu_table, "priv/templates")
  end

  def timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)

  defp valid_module?(name) do
    name =~ ~r/^[A-Z][A-Za-z0-9]*(\.[A-Z][A-Za-z0-9]*)*$/
  end

  defp valid_table?(name) do
    name =~ ~r/^[a-z][a-z0-9_]*$/
  end

  defp humanize(atom) when is_atom(atom) do
    atom |> Atom.to_string() |> humanize()
  end

  defp humanize(string) when is_binary(string) do
    string
    |> String.replace("_", " ")
    |> String.split(".")
    |> List.last()
    |> String.capitalize()
  end

  defp pluralize(word) do
    cond do
      String.ends_with?(word, "y") and not String.ends_with?(word, ["ay", "ey", "oy", "uy"]) ->
        String.slice(word, 0..-2//1) <> "ies"

      String.ends_with?(word, ["s", "sh", "ch", "x", "z"]) ->
        word <> "es"

      true ->
        word <> "s"
    end
  end

  def underscore(string) do
    string
    |> String.replace(".", "/")
    |> String.replace(~r/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
    |> String.downcase()
  end

  def camelize(string) do
    string
    |> String.split(~r/[_\/]/)
    |> Enum.map(&capitalize_first/1)
    |> Enum.join()
  end

  defp capitalize_first(<<first::utf8, rest::binary>>) do
    String.upcase(<<first::utf8>>) <> rest
  end

  defp capitalize_first(""), do: ""
end
