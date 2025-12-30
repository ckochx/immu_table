# ImmuTable Implementation Plan

## Status

**Last Updated**: 2025-12-29

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Project Setup | ✅ Complete | All dependencies installed, project compiles without warnings |
| Phase 2: Schema Macro & Field Injection | ✅ Complete | All fields injected, changeset filtering working, options stored |
| Phase 3: Insert Operations | ✅ Complete | Insert generates UUIDs, version 1, timestamps. Pipe-friendly syntax added. |
| Phase 4: Update Operations | ✅ Complete | Protected fields sanitized, tampering prevented. Pipe-friendly syntax added. |
| Phase 5: Delete Operations | ✅ Complete | Tombstone creation, field copying, error handling |
| Phase 6: Undelete Operations | ✅ Complete | Protected fields sanitized, tampering prevented |
| Phase 7: Query Helpers | ✅ Complete | current, history, at_time, all_versions, include_deleted, get, get!, fetch_current |
| Phase 8: Blocking Repo.update/delete | ✅ Complete | Blocks via module's cast/change functions (see known limitation) |
| Phase 9: Association Support | ✅ Complete | Optimized preload from O(N²) to O(1), basic functionality complete |
| Phase 10: Migration Helpers | ✅ Complete | Macros exist with full integration tests, add_immutable_indexes/1 added |
| **Demo App** | ✅ Complete | Phoenix LiveView CRUD app demonstrating all features |

---

## Latest Updates (2025-12-29)

### Ergonomic Query Functions

Added `get/3` and `get!/3` for simpler entity lookup:

```elixir
# Returns struct or nil (mirrors Repo.get/2)
user = ImmuTable.get(User, Repo, entity_id)

# Returns struct or raises Ecto.NoResultsError
user = ImmuTable.get!(User, Repo, entity_id)

# For detailed status, use fetch_current/3
case ImmuTable.fetch_current(User, Repo, entity_id) do
  {:ok, user} -> user
  {:error, :deleted} -> handle_deleted()
  {:error, :not_found} -> handle_not_found()
end
```

### Pipe-Friendly CRUD Operations

Added 2-arity versions supporting reversed argument order:

```elixir
# Insert - both work
ImmuTable.insert(Repo, changeset)
changeset |> ImmuTable.insert(Repo)

# Update from changeset - both work
ImmuTable.update(Repo, changeset)
user |> User.changeset(attrs) |> ImmuTable.update(Repo)
```

### Phoenix LiveView Demo App

Created `demo/` folder with complete Phoenix LiveView CRUD app:

- Task management with version tracking
- History timeline view
- Soft delete with tombstone view
- Restore functionality
- Routes using `entity_id` for stable URLs

See `demo/GENERATORS.md` for setup instructions.

### Test Coverage

**235 tests, 0 failures**

---

## Summary

### Completed Phases
All 10 implementation phases are now complete:
- ✅ Phase 1-8: Core functionality (insert, update, delete, undelete, queries, blocking)
- ✅ Phase 9: Association support (belongs_to, has_many, has_one with batch preloading)
- ✅ Phase 10: Migration helpers (create_immutable_table, add_immutable_indexes)
- ✅ Demo App: Phoenix LiveView CRUD example

### Resolved Issues
- ✅ Migration index helper
- ✅ Preload optimization (O(N²) → O(1))
- ✅ Migration integration tests
- ✅ Query behavior for deleted entities (fetch_current/3)
- ✅ Ergonomic get/3 and get!/3 functions
- ✅ Pipe-friendly insert/2 and update/2
- ✅ Inverse associations (has_many, has_one)
- ✅ README with comprehensive documentation

### Remaining Work (LOW Priority)
- Typespecs for public API
- Ecto.Multi integration docs
- Batch operations (insert_all, update_all)
- Hardcoded timestamp source
- Full Ecto integration for associations (cast_assoc, Repo.preload)

### Future Enhancement (MEDIUM Priority)
- **Phoenix Generator Hooks**: Create generator tasks that emit ImmuTable-compatible code:
  - `mix immu.gen.live` - Like `phx.gen.live` but with immutable schema, migration, and context
  - `mix immu.gen.html` - Like `phx.gen.html` but with ImmuTable setup
  - `mix immu.gen.context` - Generate context with ImmuTable operations
  - `mix immu.gen.schema` - Generate schema with `immutable_schema` and proper changeset
  - Should handle `entity_id` in routes, LiveView params, and templates

---

## Known Limitation: Direct Ecto.Changeset Usage

If a developer uses `Ecto.Changeset.cast` or `Ecto.Changeset.change` directly instead of the module's functions, blocking is bypassed. This is documented in tests and is a known limitation.

**Workaround**: Always use the module's `cast/3` or `change/2` functions in custom changesets:

```elixir
# CORRECT - uses module's cast, gets blocking automatically
def changeset(struct, params) do
  struct
  |> cast(params, [:name, :email])  # Module's cast
  |> validate_required([:name])
end

# INCORRECT - bypasses blocking!
def changeset(struct, params) do
  struct
  |> Ecto.Changeset.cast(params, [:name, :email])  # Direct Ecto call
  |> validate_required([:name])
end
```

---

## Other Issues (LOW Priority)

### Issue 7: No Batch Operations

No `insert_all`, `update_all` equivalents for bulk versioned inserts.

### Issue 8: No Ecto.Multi Integration

No documented way to use ImmuTable operations within `Ecto.Multi`.

### Issue 9: Hardcoded Timestamp Source

`DateTime.utc_now()` is hardcoded. No way to use database time or custom clock for testing.

### Issue 10: Missing Typespecs

No `@spec` annotations on public API functions.

### Issue 12: Handle Non-UUID Primary Keys in Migration

`add_immutable_columns/0` assumes the table will use UUID for `id`. Document that ImmuTable requires UUID primary keys.

---

## Core Concepts

### Immutability Model

- **No updates**: Instead of `UPDATE`, insert a new row with incremented version
- **No deletes**: Instead of `DELETE`, insert a tombstone row with `deleted_at` set
- **Pure append-only**: Old rows are never modified
- **Version chain**: `entity_id` + `version` identifies logical entity and its history

### Metadata Fields

| Field | Type | Purpose |
|-------|------|---------|
| `id` | UUID v7 | Primary key, time-sortable, unique per version |
| `entity_id` | UUID v7 | Groups all versions of logical entity |
| `version` | integer | Explicit version number (1, 2, 3...) |
| `valid_from` | utc_datetime_usec | When this version became active |
| `deleted_at` | utc_datetime_usec | Tombstone marker (only set on delete) |

### Current Row Resolution

The current row for an entity is determined by:

1. Find the row with `MAX(version)` for the given `entity_id`
2. If that row has `deleted_at IS NULL`, the entity is current
3. If that row has `deleted_at` set, the entity is deleted

### Tombstone Rows

When deleting, the tombstone row:
- Copies all fields from the previous version (handles NOT NULL constraints)
- Sets `deleted_at` to current timestamp
- Increments `version`

### Associations

Foreign keys reference `entity_id` (not `id`). Query helpers resolve to current versions.

### Concurrency Control

Uses PostgreSQL advisory locks on `entity_id` during update/delete operations to ensure atomic version increments.

---

## Module Structure

```
lib/
  immu_table.ex              # Main module, public API
  immu_table/
    application.ex           # Supervisor
    schema.ex                # use macro, immutable_schema
    operations.ex            # insert, update, delete, undelete
    query.ex                 # current, history, at_time, get, get!, fetch_current
    lock.ex                  # Advisory lock helpers
    changeset.ex             # Changeset helpers, field protection
    associations.ex          # immutable_belongs_to, has_many, has_one, preload
    migration.ex             # Migration helpers
    exceptions.ex            # ImmutableViolationError

demo/                        # Phoenix LiveView demo app
  lib/demo/tasks/            # Example ImmuTable schema
  lib/demo_web/live/         # LiveView CRUD with history

test/
  immu_table/
    schema_test.exs
    operations_test.exs
    query_test.exs
    lock_test.exs
    blocking_test.exs
    associations_test.exs
    migration_test.exs
  integration/
    user_integration_test.exs
```

---

## Configuration Options

```elixir
use ImmuTable,
  allow_updates: false,        # Permit Repo.update (default: false)
  allow_deletes: false,        # Permit Repo.delete (default: false)
  allow_version_write: false   # Permit writing version field (default: false)
```

---

## Success Criteria

1. ✅ All tests pass (235 tests)
2. ✅ No modifications to existing rows during update/delete operations
3. ✅ Correct current row resolution after delete/undelete cycles
4. ✅ Concurrent operations serialize correctly
5. ✅ Clear error messages when blocking direct modifications
6. ✅ Associations resolve to current versions
7. ✅ Query helpers compose with standard Ecto queries
8. ✅ Demo app demonstrates all features
