# Ecto Association Integration Analysis

## Current State

The current `immutable_belongs_to`, `immutable_has_many`, and `immutable_has_one` macros:

1. Register metadata via module attributes (`:immutable_associations`)
2. Add `*_entity_id` fields manually for `belongs_to` associations
3. Provide a custom `ImmuTable.Associations.preload/3` function
4. Do NOT call Ecto's native `belongs_to/3`, `has_many/3`, or `has_one/3` macros

## Limitations

Without Ecto's native association macros, users cannot:

- Use `Repo.preload/3` (must use `ImmuTable.Associations.preload/3`)
- Use `cast_assoc/3` in changesets
- Use `Ecto.assoc/2` to build association queries
- Define database foreign key constraints via migrations
- Use `on_replace` callbacks
- Leverage other Ecto association features

## Integration Options

### Option 1: Full Ecto Integration (Complex)

Wrap Ecto's association macros with custom options:

```elixir
defmacro immutable_belongs_to(name, queryable, opts \\ []) do
  quote do
    # Call Ecto's belongs_to with custom foreign_key and references
    Ecto.Schema.belongs_to(
      unquote(name),
      unquote(queryable),
      foreign_key: unquote(:"#{name}_entity_id"),
      references: :entity_id,
      define_field: true
    )

    # Also register in our metadata for custom preload logic
    Module.put_attribute(
      __MODULE__,
      :immutable_associations,
      {unquote(name), unquote(queryable), Keyword.put(unquote(opts), :type, :belongs_to)}
    )
  end
end
```

**Pros:**
- Enables `Repo.preload/3` usage
- Enables `cast_assoc/3` and other Ecto features
- FK constraints can be defined in migrations
- Feels more "Ecto native"

**Cons:**
- Ecto's preload would load by `id` matching, not respecting versioning (loads all versions, not just current)
- Would need to override/wrap `Repo.preload/3` behavior to filter to current versions
- Complex interactions with Ecto's query builder
- May cause confusion about which preload to use
- FK constraints on `entity_id` may have performance implications

### Option 2: Hybrid Approach

Keep current custom implementation but add helpers for common Ecto patterns:

```elixir
# Add Ecto.Multi helpers
def insert_multi(multi, name, struct_or_changeset) do
  Ecto.Multi.run(multi, name, fn repo, _changes ->
    ImmuTable.insert(repo, struct_or_changeset)
  end)
end

# Add association query builder
def assoc_query(struct, assoc_name) do
  # Build query similar to Ecto.assoc/2 but for immutable schemas
end
```

**Pros:**
- Maintains control over versioning semantics
- Simpler to implement and test
- Clear separation between Ecto and ImmuTable APIs
- Less risk of version-related bugs

**Cons:**
- Still requires custom API instead of standard Ecto patterns
- Developers need to learn ImmuTable-specific APIs

### Option 3: Documentation-Only (Current)

Document the limitations clearly and provide migration guides for common patterns.

**Pros:**
- No breaking changes
- Clear, explicit API
- No hidden version-related gotchas

**Cons:**
- Less ergonomic for users familiar with Ecto
- May limit adoption

## Recommendation

**Short term:** Option 2 (Hybrid Approach)
- Add `Ecto.Multi` integration helpers (addresses Issue #8)
- Add convenience functions for common patterns
- Improve documentation with examples

**Long term:** Consider Option 1 if there's strong user demand
- Would require careful design to avoid version-related bugs
- Would need comprehensive testing of Ecto integration
- Could be gated behind a config option (`use ImmuTable, ecto_integration: true`)

## Implementation Plan for Short Term

1. Add `ImmuTable.Multi` module with helpers:
   - `insert/4` - wrap ImmuTable.insert in Ecto.Multi
   - `update/4` - wrap ImmuTable.update in Ecto.Multi
   - `delete/3` - wrap ImmuTable.delete in Ecto.Multi
   - `undelete/4` - wrap ImmuTable.undelete in Ecto.Multi

2. Add convenience query builders:
   - `assoc_subquery/2` - build subquery for association (respects versioning)

3. Add comprehensive documentation:
   - Common patterns guide
   - Migration guide from standard Ecto
   - Cookbook with real examples

## Related Issues

- Issue #7: No batch operations (addressed by Multi helpers)
- Issue #8: No Ecto.Multi integration (addressed by Multi helpers)
