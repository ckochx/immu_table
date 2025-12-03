defmodule ImmuTable.Associations do
  @moduledoc """
  Macros and helpers for defining immutable-aware associations.

  Associations in immutable schemas reference entity_id instead of id,
  ensuring relationships persist across versions.
  """

  defmacro immutable_belongs_to(name, queryable, opts \\ []) do
    quote do
      field(unquote(:"#{name}_entity_id"), Ecto.UUID)

      Module.put_attribute(
        __MODULE__,
        :immutable_associations,
        {unquote(name), unquote(queryable), Keyword.put(unquote(opts), :type, :belongs_to)}
      )
    end
  end

  defmacro immutable_has_many(name, queryable, opts \\ []) do
    quote do
      Module.put_attribute(
        __MODULE__,
        :immutable_associations,
        {unquote(name), unquote(queryable), Keyword.put(unquote(opts), :type, :has_many)}
      )
    end
  end

  defmacro immutable_has_one(name, queryable, opts \\ []) do
    quote do
      Module.put_attribute(
        __MODULE__,
        :immutable_associations,
        {unquote(name), unquote(queryable), Keyword.put(unquote(opts), :type, :has_one)}
      )
    end
  end

  def preload(struct_or_structs, repo, assoc) when is_list(struct_or_structs) do
    if struct_or_structs == [] do
      []
    else
      # Extract common data from first struct
      [first | _] = struct_or_structs
      module = first.__struct__
      {assoc_module, opts} = get_association_info(module, assoc)
      assoc_type = Keyword.get(opts, :type, :belongs_to)

      case assoc_type do
        :belongs_to ->
          preload_belongs_to_list(struct_or_structs, repo, assoc, assoc_module)

        :has_many ->
          preload_has_many_list(struct_or_structs, repo, assoc, assoc_module, opts)

        :has_one ->
          preload_has_one_list(struct_or_structs, repo, assoc, assoc_module, opts)
      end
    end
  end

  def preload(struct, repo, assoc) when is_atom(assoc) do
    module = struct.__struct__
    {assoc_module, opts} = get_association_info(module, assoc)
    assoc_type = Keyword.get(opts, :type, :belongs_to)

    case assoc_type do
      :belongs_to ->
        preload_belongs_to_single(struct, repo, assoc, assoc_module)

      :has_many ->
        preload_has_many_single(struct, repo, assoc, assoc_module, opts)

      :has_one ->
        preload_has_one_single(struct, repo, assoc, assoc_module, opts)
    end
  end

  # Belongs_to preloading
  defp preload_belongs_to_list(struct_or_structs, repo, assoc, assoc_module) do
    entity_id_field = :"#{assoc}_entity_id"

    # Collect all entity_ids from the list
    entity_ids =
      struct_or_structs
      |> Enum.map(&Map.get(&1, entity_id_field))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    # Batch query: get all current versions in one query
    import Ecto.Query

    assoc_records =
      if entity_ids == [] do
        []
      else
        assoc_module
        |> ImmuTable.Query.get_current()
        |> where([a], a.entity_id in ^entity_ids)
        |> repo.all()
      end

    # Build a map of entity_id -> record for fast lookup
    assoc_map =
      assoc_records
      |> Enum.map(&{&1.entity_id, &1})
      |> Map.new()

    # Map each struct to its preloaded version
    Enum.map(struct_or_structs, fn struct ->
      entity_id = Map.get(struct, entity_id_field)
      assoc_record = if entity_id, do: Map.get(assoc_map, entity_id), else: nil
      Map.put(struct, assoc, assoc_record)
    end)
  end

  defp preload_belongs_to_single(struct, repo, assoc, assoc_module) do
    entity_id_field = :"#{assoc}_entity_id"
    entity_id = Map.get(struct, entity_id_field)

    if entity_id do
      import Ecto.Query

      assoc_record =
        assoc_module
        |> ImmuTable.Query.get_current()
        |> where([a], a.entity_id == ^entity_id)
        |> repo.one()

      Map.put(struct, assoc, assoc_record)
    else
      Map.put(struct, assoc, nil)
    end
  end

  # Has_many preloading
  defp preload_has_many_list(struct_or_structs, repo, assoc, assoc_module, opts) do
    foreign_key = Keyword.get(opts, :foreign_key) ||
      raise ArgumentError, "has_many associations require :foreign_key option"

    # Collect all entity_ids from parent structs
    parent_entity_ids =
      struct_or_structs
      |> Enum.map(& &1.entity_id)
      |> Enum.uniq()

    # Batch query: get all associated records
    import Ecto.Query

    assoc_records =
      if parent_entity_ids == [] do
        []
      else
        assoc_module
        |> ImmuTable.Query.get_current()
        |> where([a], field(a, ^foreign_key) in ^parent_entity_ids)
        |> repo.all()
      end

    # Group by parent entity_id
    grouped_assocs =
      assoc_records
      |> Enum.group_by(&Map.get(&1, foreign_key))

    # Map each struct to its preloaded associations
    Enum.map(struct_or_structs, fn struct ->
      records = Map.get(grouped_assocs, struct.entity_id, [])
      Map.put(struct, assoc, records)
    end)
  end

  defp preload_has_many_single(struct, repo, assoc, assoc_module, opts) do
    foreign_key = Keyword.get(opts, :foreign_key) ||
      raise ArgumentError, "has_many associations require :foreign_key option"

    import Ecto.Query

    assoc_records =
      assoc_module
      |> ImmuTable.Query.get_current()
      |> where([a], field(a, ^foreign_key) == ^struct.entity_id)
      |> repo.all()

    Map.put(struct, assoc, assoc_records)
  end

  # Has_one preloading
  defp preload_has_one_list(struct_or_structs, repo, assoc, assoc_module, opts) do
    foreign_key = Keyword.get(opts, :foreign_key) ||
      raise ArgumentError, "has_one associations require :foreign_key option"

    # Collect all entity_ids from parent structs
    parent_entity_ids =
      struct_or_structs
      |> Enum.map(& &1.entity_id)
      |> Enum.uniq()

    # Batch query: get all associated records
    import Ecto.Query

    assoc_records =
      if parent_entity_ids == [] do
        []
      else
        assoc_module
        |> ImmuTable.Query.get_current()
        |> where([a], field(a, ^foreign_key) in ^parent_entity_ids)
        |> repo.all()
      end

    # Build map (take first record per parent for has_one)
    assoc_map =
      assoc_records
      |> Enum.group_by(&Map.get(&1, foreign_key))
      |> Enum.map(fn {key, records} -> {key, List.first(records)} end)
      |> Map.new()

    # Map each struct to its preloaded association
    Enum.map(struct_or_structs, fn struct ->
      record = Map.get(assoc_map, struct.entity_id)
      Map.put(struct, assoc, record)
    end)
  end

  defp preload_has_one_single(struct, repo, assoc, assoc_module, opts) do
    foreign_key = Keyword.get(opts, :foreign_key) ||
      raise ArgumentError, "has_one associations require :foreign_key option"

    import Ecto.Query

    assoc_record =
      assoc_module
      |> ImmuTable.Query.get_current()
      |> where([a], field(a, ^foreign_key) == ^struct.entity_id)
      |> limit(1)
      |> repo.one()

    Map.put(struct, assoc, assoc_record)
  end

  def join(query, assoc) when is_atom(assoc) do
    import Ecto.Query

    schema = get_query_schema(query)
    entity_id_field = :"#{assoc}_entity_id"
    assoc_module = get_association_module(schema, assoc)

    current_assoc_query =
      assoc_module
      |> ImmuTable.Query.get_current()

    from(q in query,
      join: a in subquery(current_assoc_query),
      on: field(q, ^entity_id_field) == a.entity_id,
      as: ^assoc
    )
  end

  defp get_query_schema(%Ecto.Query{from: %{source: {_table, schema}}}) when schema != nil do
    schema
  end

  defp get_query_schema(%Ecto.Query{from: %{source: {_table, nil}}}) do
    raise ArgumentError, "cannot determine schema from query"
  end

  defp get_query_schema(schema) when is_atom(schema) do
    schema
  end

  defp get_association_info(module, assoc_name) do
    associations = module.__associations__()

    case Map.get(associations, assoc_name) do
      {assoc_module, opts} -> {assoc_module, opts}
      nil -> raise ArgumentError, "association #{assoc_name} not found on #{module}"
    end
  end

  defp get_association_module(module, assoc_name) do
    {assoc_module, _opts} = get_association_info(module, assoc_name)
    assoc_module
  end
end
