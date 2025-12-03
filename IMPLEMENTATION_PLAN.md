# ImmuTable Implementation Plan

## Status

**Last Updated**: 2025-12-03

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Project Setup | ✅ Complete | All dependencies installed, project compiles without warnings |
| Phase 2: Schema Macro & Field Injection | ✅ Complete | All fields injected, changeset filtering working, options stored |
| Phase 3: Insert Operations | ✅ Complete | Insert generates UUIDs, version 1, timestamps |
| Phase 4: Update Operations | ✅ Fixed | Protected fields sanitized, tampering prevented |
| Phase 5: Delete Operations | ✅ Complete | Tombstone creation, field copying, error handling |
| Phase 6: Undelete Operations | ✅ Fixed | Protected fields sanitized, tampering prevented |
| Phase 7: Query Helpers | ✅ Complete | current, history, at_time, all_versions, include_deleted |
| Phase 8: Blocking Repo.update/delete | ✅ Fixed | Blocks via module's cast/change functions (see known limitation) |
| Phase 9: Association Support | ⚠️ Incomplete | Basic functionality works, but O(N²), no Ecto integration |
| Phase 10: Migration Helpers | ⚠️ Untested | Macros exist but no integration tests verify SQL output |

---

## Fixes Applied (2025-12-03)

### Fix 1: Elixir Version Constraint ✅

Changed `elixir: "~> 1.19"` to `elixir: "~> 1.14"` in `mix.exs`.

### Fix 2: Metadata Tampering Prevention ✅

**Location**: `lib/immu_table/operations.ex`

Protected fields (`id`, `entity_id`, `version`, `valid_from`, `deleted_at`) are now:
1. Filtered from user-provided changes before merging
2. Explicitly set to correct values after merging

```elixir
@protected_fields [:id, :entity_id, :version, :valid_from, :deleted_at]

defp prepare_update_changeset(current, changes) when is_map(changes) do
  safe_changes =
    changes
    |> normalize_keys()
    |> Map.drop(@protected_fields)

  # ... merge safe_changes ...
  # Then explicitly set protected fields:
  |> Ecto.Changeset.put_change(:id, generate_uuid())
  |> Ecto.Changeset.put_change(:entity_id, current.entity_id)  # Preserved!
  |> Ecto.Changeset.put_change(:version, current.version + 1)
  |> Ecto.Changeset.put_change(:valid_from, DateTime.utc_now())
  |> Ecto.Changeset.put_change(:deleted_at, nil)  # Always nil for updates!
end
```

**Tests Added**: 10 new tests in `test/immu_table/operations_test.exs` verify tampering is prevented.

### Fix 3: Blocking for Custom Changesets ✅

**Location**: `lib/immu_table/schema.ex`

The module's `cast/3` and `change/2` functions now automatically inject blocking via `__ensure_immutable_blocking__/1`. This means:

- Schemas using the module's `cast/3` get blocking automatically
- Schemas using the module's `change/2` get blocking automatically
- Developers don't need to call `maybe_block_updates/maybe_block_deletes` manually

**Tests Added**: 4 new tests verify blocking works with custom changesets.

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

## Remaining Issues

### Issue 3: Association Support Is Incomplete [MEDIUM]

**Location**: `lib/immu_table/associations.ex`

**Problems**:
1. `immutable_belongs_to/3` only creates a field, not an actual Ecto association
   - `Repo.preload/2` doesn't work (Ecto doesn't know about the association)
   - `cast_assoc/3` doesn't work
   - `Ecto.assoc/2` doesn't work
   - No foreign key constraints

2. `ImmuTable.preload/3` is O(N²) - runs a separate query per parent record
   ```elixir
   def preload(struct_or_structs, repo, assoc) when is_list(struct_or_structs) do
     Enum.map(struct_or_structs, fn struct ->
       preload(struct, repo, assoc)  # <-- N queries for N parents!
     end)
   end
   ```

**Fix Required**:
1. Consider using actual `belongs_to` with custom foreign_key pointing to `*_entity_id`
2. Batch preload: collect all entity_ids, run single query, then match results
3. Document limitations clearly if full Ecto integration not implemented

---

### Issue 4: Migration Tests Don't Verify SQL Output [MEDIUM]

**Location**: `test/immu_table/migration_test.exs`

**Problem**: Tests only verify that macros are exported and have documentation. No tests verify:
- Correct SQL is generated
- Indexes are actually created
- Column types are correct

**Fix Required**:
1. Add integration tests that run migrations and verify table structure
2. Or: Test the expanded AST to verify correct Ecto.Migration calls

---

## Other Issues

### Issue 5: Missing has_many/has_one Inverse Associations [MEDIUM]

Only `immutable_belongs_to` exists. No way to define the inverse side.

---

### Issue 7: No Batch Operations [LOW]

No `insert_all`, `update_all` equivalents for bulk versioned inserts.

---

### Issue 8: No Ecto.Multi Integration [LOW]

No documented way to use ImmuTable operations within `Ecto.Multi`.

---

### Issue 9: Hardcoded Timestamp Source [LOW]

`DateTime.utc_now()` is hardcoded. No way to use database time or custom clock for testing.

---

### Issue 10: Missing Typespecs [LOW]

No `@spec` annotations on public API functions.

---

### Issue 11: Minimal README [LOW]

README lacks usage examples, migration setup guide, query helper examples.

---

## Test Coverage Gaps

| Area | Gap |
|------|-----|
| ~~Metadata tampering~~ | ✅ Fixed - 10 tests added |
| ~~Custom changeset blocking~~ | ✅ Fixed - 4 tests added |
| Migration SQL | No integration tests verify actual table/index creation |
| Association edge cases | No tests for invalid association names, bulk preload efficiency |
| `at_time` boundaries | No tests for exact boundary conditions |

---

## Recommended Next Steps

1. **Optimize preload** to batch queries (O(N²) → O(1))
2. **Add migration integration tests**
3. **Add typespecs and improve documentation**

### Phase 1 Completion Details

**Completed**: 2025-12-02

✅ Created mix project with supervisor
✅ Added dependencies: `ecto_sql`, `uuidv7`, `postgrex`
✅ Configured test database and Ecto.Repo
✅ Created basic module structure (all stub files)
✅ Project compiles with warnings-as-errors enabled

**Files Created**:
- `mix.exs` - Project configuration with dependencies
- `config/config.exs`, `config/test.exs` - Configuration files
- `lib/immu_table/application.ex` - Supervisor with TestRepo in test env
- `test/support/test_repo.ex` - Test repository
- `test/support/data_case.ex` - Test case template with sandbox
- Stub modules: `schema.ex`, `operations.ex`, `query.ex`, `lock.ex`, `changeset.ex`, `associations.ex`, `migration.ex`, `exceptions.ex`

---

### Phase 2 Completion Details

**Completed**: 2025-12-02

✅ Implemented `use ImmuTable` macro with options parsing
✅ Created `immutable_schema/2` macro wrapping `Ecto.Schema.schema/2`
✅ Injected required fields: `entity_id`, `version`, `valid_from`, `deleted_at`
✅ Configured UUIDv7 as primary key type
✅ Implemented changeset filtering via custom `cast/3` function
✅ Stored options in module attributes accessible via `__immutable__/1`

**Files Implemented**:
- `lib/immu_table.ex` - `__using__/1` macro
- `lib/immu_table/schema.ex` - `immutable_schema/2` macro, `__before_compile__/1` callback
- `test/support/test_schemas.ex` - Test schemas with various configurations
- `test/immu_table/schema_test.exs` - Comprehensive tests (12 tests, all passing)
- `docker-compose.yml` - PostgreSQL test database configuration

**Test Results**: 13/13 tests passing, compiles without warnings

---

### Phase 3 Completion Details

**Completed**: 2025-12-02

✅ Implemented `insert/2` and `insert!/2` operations
✅ Auto-generates UUIDv7 for `id` and `entity_id`
✅ Sets `version: 1` for initial insert
✅ Sets `valid_from` to current timestamp
✅ Ensures `deleted_at: nil`
✅ Works with both struct and changeset inputs

**Files Implemented**:
- `lib/immu_table/operations.ex` - Core insert operations
- `lib/immu_table.ex` - Delegated public API
- `test/immu_table/operations_test.exs` - Comprehensive tests (12 tests)
- `priv/test_repo/migrations/20251202000001_create_test_tables.exs` - Test database schema
- `config/config.exs` - Added ecto_repos configuration

**Test Results**: 25/25 tests passing, compiles without warnings

---

### Phase 4 Completion Details

**Completed**: 2025-12-02

✅ Implemented `update/3` and `update!/3` operations
✅ Creates new version row with incremented version number
✅ Old rows remain completely untouched (append-only)
✅ Advisory locks prevent concurrent version conflicts
✅ Fetches current version from database before updating
✅ Handles not found and deleted entity errors
✅ Works with map and changeset inputs
✅ Concurrent updates serialize correctly via PostgreSQL locks

**Files Implemented**:
- `lib/immu_table/operations.ex` - Update operations with version increment
- `lib/immu_table/lock.ex` - PostgreSQL advisory lock wrapper
- `lib/immu_table.ex` - Delegated public API for update
- `test/immu_table/operations_test.exs` - 14 update tests including concurrency
- `test/immu_table/lock_test.exs` - 4 advisory lock tests

**Test Results**: 43/43 tests passing (1 skipped for Phase 5)

---

### Phase 5 Completion Details

**Completed**: 2025-12-02

✅ Implemented `delete/2` and `delete!/2` operations
✅ Creates tombstone row with `deleted_at` timestamp
✅ Copies all data fields from current version
✅ Increments version number
✅ Updates `valid_from` to current timestamp
✅ Generates new UUIDv7 for tombstone `id`
✅ Preserves `entity_id` across tombstone
✅ Uses advisory locks for concurrency control
✅ Returns error if entity not found
✅ Returns error if entity already deleted
✅ Old rows remain completely untouched (append-only)

**Files Implemented**:
- `lib/immu_table/operations.ex` - Added `delete/2`, `delete!/2`, `prepare_delete_changeset/1`
- `lib/immu_table.ex` - Delegated public API for delete operations
- `test/immu_table/operations_test.exs` - 14 comprehensive delete tests

**Test Results**: 57/57 tests passing (all delete tests now enabled)

---

### Phase 6 Completion Details

**Completed**: 2025-12-02

✅ Implemented `undelete/2` and `undelete!/2` operations
✅ Restores tombstoned entities by creating new row with `deleted_at: nil`
✅ Copies all data fields from tombstone version
✅ Increments version number from tombstone
✅ Updates `valid_from` to current timestamp
✅ Generates new UUIDv7 for restored `id`
✅ Preserves `entity_id` across restoration
✅ Uses advisory locks for concurrency control
✅ Accepts optional changes to apply during undelete
✅ Returns error if entity not found
✅ Returns error if entity not deleted
✅ Supports delete/undelete cycles correctly
✅ Old rows (including tombstones) remain untouched

**Files Implemented**:
- `lib/immu_table/operations.ex` - Added `undelete/2`, `undelete!/2`, `fetch_latest_version/2`, `prepare_undelete_changeset/2`
- `lib/immu_table.ex` - Delegated public API for undelete operations
- `test/immu_table/operations_test.exs` - 15 comprehensive undelete tests

**Test Results**: 72/72 tests passing (all CRUD operations complete)

---

### Phase 7 Completion Details

**Completed**: 2025-12-02

✅ Implemented `current/1` - returns latest non-deleted version of each entity
✅ Implemented `history/2` - returns all versions of a specific entity
✅ Implemented `at_time/2` - returns versions valid at specific timestamp
✅ Implemented `all_versions/1` - returns all rows without filtering
✅ Implemented `include_deleted/1` - returns latest versions including tombstones
✅ All query helpers compose with standard Ecto queries
✅ Efficient implementation using subqueries with max(version)
✅ Handles delete/undelete cycles correctly

**Files Implemented**:
- `lib/immu_table/query.ex` - All query helper functions with composable design
- `test/immu_table/query_test.exs` - 18 comprehensive query tests

**Test Results**: 117/117 tests passing (99 existing + 18 query tests)

**Query Helper Examples**:
```elixir
# Get current (non-deleted) users
User |> ImmuTable.Query.current() |> Repo.all()

# Get complete history of a user
User |> ImmuTable.Query.history(entity_id) |> Repo.all()

# Time travel query
User |> ImmuTable.Query.at_time(~U[2024-01-15 10:00:00Z]) |> Repo.all()

# Include deleted in results
User |> ImmuTable.Query.include_deleted() |> Repo.all()
```

---

### Phase 8 Completion Details

**Completed**: 2025-12-02

✅ Implemented `ImmuTable.ImmutableViolationError` exception
✅ Created blocking logic via `Ecto.Changeset.prepare_changes/2`
✅ Injected `maybe_block_updates/2` and `maybe_block_deletes/2` helpers
✅ Auto-inject blocking into schemas without custom changeset
✅ Provided helper functions for schemas with custom changesets
✅ Respected `allow_updates: true` and `allow_deletes: true` options
✅ Clear, actionable error messages guide users to correct API

**Files Implemented**:
- `lib/immu_table/exceptions.ex` - `ImmuTable.ImmutableViolationError` exception
- `lib/immu_table/changeset.ex` - `block_updates/2` and `block_deletes/2` functions
- `lib/immu_table/schema.ex` - Injected blocking helpers and optional default changeset
- `test/immu_table/blocking_test.exs` - 8 comprehensive blocking tests
- `test/integration/user_integration_test.exs` - 4 additional blocking scenarios
- `priv/test_repo/migrations/20251202000003_create_blocking_test_tables.exs` - Test tables for blocking tests

**Test Results**: 129/129 tests passing (117 existing + 8 blocking tests + 4 integration tests)

**Implementation Notes**:
- Blocking happens via `prepare_changes` callback, executed during transaction
- Default `changeset/2` function injected for schemas without custom implementation
- Schemas with custom changesets call `maybe_block_updates/2` and `maybe_block_deletes/2` explicitly
- Conditional compilation: only inject default changeset if not already defined
- Error messages include schema name and suggest using `ImmuTable.update/3` or `ImmuTable.delete/2`

---

### Phase 9 Completion Details

**Completed**: 2025-12-02

✅ Implemented `immutable_belongs_to/3` macro for defining associations
✅ Created `{field}_entity_id` fields instead of standard `{field}_id`
✅ Implemented `ImmuTable.preload/3` to load current versions of associations
✅ Handles single struct and list of structs for preloading
✅ Preload resolves to current version after associated entity updates
✅ Preload returns nil for deleted associations
✅ Implemented `ImmuTable.join/2` for joining with current association versions
✅ Join excludes deleted associations automatically
✅ Registered `:immutable_associations` as accumulate attribute
✅ Created `__associations__/0` function for runtime access to association metadata

**Files Implemented**:
- `lib/immu_table/associations.ex` - Association macro and helpers
- `lib/immu_table.ex` - Added preload and join delegations, registered associations attribute
- `lib/immu_table/schema.ex` - Added `__associations__/0` function injection
- `test/immu_table/associations_test.exs` - 13 comprehensive association tests
- `priv/test_repo/migrations/20251202000004_create_association_test_tables.exs` - Test tables for associations

**Test Results**: 142/142 tests passing (129 existing + 13 association tests)

**Implementation Notes**:
- Associations reference `entity_id` instead of `id` for version-stable relationships
- Preload uses `ImmuTable.Query.current()` to resolve to latest non-deleted version
- Join creates inner join with current subquery and excludes deleted associations
- Association metadata stored at compile time via `@immutable_associations` attribute
- Runtime access via `__associations__/0` function returns map of `%{name => {module, opts}}`
- Join bindings require accounting for `current()` subquery binding when using positional references

---

### Phase 10 Completion Details

**Completed**: 2025-12-02

✅ Created `ImmuTable.Migration` module with helper macros
✅ Implemented `create_immutable_table/2` macro for creating tables
✅ Auto-adds all required immutable columns (id, entity_id, version, valid_from, deleted_at)
✅ Auto-creates recommended indexes (entity_id, entity_id+version composite, valid_from)
✅ Supports custom columns in do block
✅ Implemented `add_immutable_columns/0` macro for converting existing tables
✅ Comprehensive documentation with usage examples
✅ Macros merge provided options with defaults (primary_key: false)

**Files Implemented**:
- `lib/immu_table/migration.ex` - Migration helper macros with documentation
- `test/immu_table/migration_test.exs` - 4 tests verifying macro exports and documentation

**Test Results**: 146/146 tests passing (142 existing + 4 migration tests)

**Implementation Notes**:
- `create_immutable_table` sets `primary_key: false` and creates uuid id column
- Automatically adds three indexes: entity_id, (entity_id, version), valid_from
- `add_immutable_columns` for use in `alter table` blocks when converting existing tables
- Macros expand at compile time to generate standard Ecto.Migration code
- Users import `ImmuTable.Migration` in their migration modules

**Usage Example**:
```elixir
defmodule MyApp.Repo.Migrations.CreateUsers do
  use Ecto.Migration
  import ImmuTable.Migration

  def change do
    create_immutable_table :users do
      add :email, :string
      add :name, :string
    end
  end
end
```

---

## Overview

ImmuTable is an Elixir library that makes Ecto tables immutable. Instead of updating or deleting rows, new rows are inserted with version tracking metadata. This provides a complete audit trail and enables point-in-time queries.

## Core Concepts

### Immutability Model

- **No updates**: Instead of `UPDATE`, insert a new row with incremented version
- **No deletes**: Instead of `DELETE`, insert a tombstone row with `deleted_at` set
- **Pure append-only**: Old rows are never modified
- **Version chain**: `entity_id` + `version` identifies logical entity and its history

### Metadata Fields

| Field | Type | Purpose |
|-------|------|---------|
| `id` | UUID v7 | Primary key, time-sortable |
| `entity_id` | UUID v7 | Groups all versions of logical entity |
| `version` | integer | Explicit version number (1, 2, 3...) |
| `valid_from` | utc_datetime_usec | When this version became active |
| `deleted_at` | utc_datetime_usec | Tombstone marker (only set on delete) |

### Current Row Resolution

The current row for an entity is determined by:

1. Find the row with `MAX(version)` for the given `entity_id`
2. If that row has `deleted_at IS NULL`, the entity is current
3. If that row has `deleted_at` set, the entity is deleted

This approach correctly handles delete/undelete cycles:

```
v1: {name: "foo", deleted_at: nil}     ← was current
v2: {name: "foo", deleted_at: ~U[...]} ← tombstone (deleted)
v3: {name: "foo", deleted_at: nil}     ← current (undeleted)
```

### Tombstone Rows

When deleting, the tombstone row:
- Copies all fields from the previous version (handles NOT NULL constraints)
- Sets `deleted_at` to current timestamp
- Increments `version`

### Associations

Foreign keys reference `entity_id` (not `id`). Query helpers resolve to current versions.

### Concurrency Control

Uses PostgreSQL advisory locks on `entity_id` during update/delete operations to ensure atomic version increments.

### Blocking Direct Modifications

By default, `Repo.update` and `Repo.delete` are blocked on immutable schemas. Configurable via:

```elixir
use ImmuTable, allow_updates: true
use ImmuTable, allow_deletes: true
```

---

## Target API

```elixir
defmodule MyApp.Account do
  use Ecto.Schema
  use ImmuTable

  immutable_schema "accounts" do
    field :name, :string
    field :balance, :decimal

    immutable_belongs_to :user, MyApp.User
  end
end

# Insert
{:ok, account} = ImmuTable.insert(Repo, %Account{name: "Checking", balance: 100})
# => %Account{id: <uuid>, entity_id: <uuid>, version: 1, ...}

# Update (creates new version)
{:ok, updated} = ImmuTable.update(Repo, account, %{balance: 150})
# => %Account{id: <new-uuid>, entity_id: <same-uuid>, version: 2, ...}

# Delete (creates tombstone)
{:ok, deleted} = ImmuTable.delete(Repo, account)
# => %Account{..., version: 3, deleted_at: ~U[...]}

# Undelete
{:ok, restored} = ImmuTable.undelete(Repo, deleted)
# => %Account{..., version: 4, deleted_at: nil}

# Query current versions
Account |> ImmuTable.current() |> Repo.all()

# Query history
Account |> ImmuTable.history(entity_id) |> Repo.all()

# Query at point in time
Account |> ImmuTable.at_time(~U[2024-01-15 10:00:00Z]) |> Repo.all()
```

---

## Implementation Phases

### Phase 1: Project Setup

**Objective**: Create mix project with required dependencies and structure.

**Tasks**:
- Create mix project with `--sup` flag
- Add dependencies: `ecto_sql`, `uuidv7`, `postgrex` (dev/test)
- Configure test database
- Set up basic module structure

**Tests**:
- Project compiles
- Dependencies resolve

**Files**:
- `mix.exs`
- `lib/immu_table.ex`
- `lib/immu_table/application.ex`
- `config/config.exs`
- `config/test.exs`

---

### Phase 2: Schema Macro & Field Injection

**Objective**: Implement `use ImmuTable` macro that injects required fields.

**Tasks**:
- Create `ImmuTable.Schema` module
- Implement `__using__/1` macro with options parsing
- Create `immutable_schema/2` macro wrapping `Ecto.Schema.schema/2`
- Inject fields: `entity_id`, `version`, `valid_from`, `deleted_at`
- Configure UUIDv7 as primary key type
- Mark `version` as non-writable by default (via changeset filtering)

**Tests**:
- Schema has all required fields with correct types
- `version` rejected in changeset by default
- `version` accepted when `allow_version_write: true`
- Options correctly parsed and stored in module attributes

**Files**:
- `lib/immu_table/schema.ex`
- `test/immu_table/schema_test.exs`
- `test/support/test_schemas.ex`

---

### Phase 3: Insert Operations

**Objective**: Implement insert that auto-generates immutability metadata.

**Tasks**:
- Create `ImmuTable.Operations` module
- Implement `insert/2` and `insert!/2`
- Generate UUIDv7 for `id` and `entity_id`
- Set `version: 1`, `valid_from: DateTime.utc_now()`
- Ensure `deleted_at: nil`

**Tests**:
- Insert generates correct `id` (UUIDv7)
- Insert generates correct `entity_id` (UUIDv7)
- `version` is 1
- `valid_from` is set to current time
- `deleted_at` is nil
- Works with changeset input
- Works with struct input

**Files**:
- `lib/immu_table/operations.ex`
- `test/immu_table/operations_test.exs`

---

### Phase 4: Update Operations (Versioned Insert)

**Objective**: Implement update that creates a new version row.

**Tasks**:
- Implement `update/3` and `update!/3`
- Create `ImmuTable.Lock` module for advisory locks
- Acquire advisory lock on `entity_id`
- Fetch current version number from database
- Insert new row with: same `entity_id`, `version + 1`, new `valid_from`, merged changes
- Release lock (automatic on transaction end)
- Handle changeset and map inputs

**Tests**:
- New row created with incremented version
- Old row completely untouched (verify all fields)
- `entity_id` preserved across versions
- Changes applied to new row
- `valid_from` updated to current time
- Concurrent updates serialize correctly (no duplicate versions)
- Lock prevents race conditions
- Returns error if entity not found
- Returns error if entity is deleted (tombstoned)

**Files**:
- `lib/immu_table/operations.ex` (extend)
- `lib/immu_table/lock.ex`
- `test/immu_table/lock_test.exs`
- `test/immu_table/operations_test.exs` (extend)

---

### Phase 5: Delete Operations (Tombstone)

**Objective**: Implement delete that creates a tombstone row.

**Tasks**:
- Implement `delete/2` and `delete!/2`
- Acquire advisory lock on `entity_id`
- Copy all fields from current version
- Insert tombstone: same `entity_id`, `version + 1`, `deleted_at: now`
- All other fields duplicated from previous version

**Tests**:
- Tombstone row created
- All data fields copied from previous version
- `deleted_at` set to current time
- `version` incremented
- `valid_from` set to current time
- Returns error if entity already deleted
- Returns error if entity not found

**Files**:
- `lib/immu_table/operations.ex` (extend)
- `test/immu_table/operations_test.exs` (extend)

---

### Phase 6: Undelete Operations

**Objective**: Implement undelete that restores a tombstoned entity.

**Tasks**:
- Implement `undelete/2` and `undelete!/2`
- Acquire advisory lock on `entity_id`
- Copy all fields from tombstone row
- Insert new row: `version + 1`, `deleted_at: nil`
- Optionally accept changes to apply during undelete

**Tests**:
- New current row created from tombstone data
- `deleted_at` is nil on restored row
- `version` incremented
- Entity appears in current queries again
- Returns error if entity not deleted
- Returns error if entity not found
- Optional changes applied during undelete

**Files**:
- `lib/immu_table/operations.ex` (extend)
- `test/immu_table/operations_test.exs` (extend)

---

### Phase 7: Query Helpers

**Objective**: Implement query composable functions for immutable tables.

**Tasks**:
- Create `ImmuTable.Query` module
- Implement `current/1` - latest version per entity where `deleted_at IS NULL`
- Implement `history/2` - all versions of entity ordered by version
- Implement `at_time/2` - version valid at specific timestamp
- Implement `all_versions/1` - no filtering, all rows
- Implement `include_deleted/1` - latest versions including tombstones
- Use subqueries for efficient current resolution

**Tests**:
- `current/1` excludes old versions
- `current/1` excludes deleted entities
- `current/1` returns undeleted entities correctly (after delete/undelete cycle)
- `history/2` returns all versions in order
- `history/2` includes tombstone rows
- `at_time/2` returns correct historical version
- `at_time/2` returns nil/empty for time before entity existed
- `include_deleted/1` includes tombstoned entities
- All helpers compose with other Ecto queries

**Files**:
- `lib/immu_table/query.ex`
- `test/immu_table/query_test.exs`

---

### Phase 8: Blocking Repo.update/delete

**Objective**: Prevent direct Repo operations on immutable schemas.

**Tasks**:
- Create `ImmuTable.Changeset` module
- Implement blocking via `Ecto.Changeset.prepare_changes/2`
- Store `__immutable__` metadata in schema
- Create `ImmuTable.ImmutableViolationError` exception
- Raise on blocked operations
- Respect `allow_updates: true` option
- Respect `allow_deletes: true` option
- Provide clear error messages

**Tests**:
- `Repo.update` raises `ImmutableViolationError` by default
- `Repo.delete` raises `ImmutableViolationError` by default
- `allow_updates: true` permits `Repo.update`
- `allow_deletes: true` permits `Repo.delete`
- Error messages are helpful

**Files**:
- `lib/immu_table/changeset.ex`
- `lib/immu_table/exceptions.ex`
- `test/immu_table/blocking_test.exs`

---

### Phase 9: Association Support

**Objective**: Implement immutable-aware associations.

**Tasks**:
- Create `ImmuTable.Associations` module
- Implement `immutable_belongs_to/3` macro
- Store `{field}_entity_id` instead of `{field}_id`
- Implement preload helper that resolves to current versions
- Implement join helpers for queries
- Handle case where associated entity is deleted

**Tests**:
- `immutable_belongs_to` creates correct field
- Association stores `entity_id`
- Preload returns current version of associated entity
- Preload works after associated entity updated
- Join queries work correctly
- Graceful handling of deleted associations

**Files**:
- `lib/immu_table/associations.ex`
- `test/immu_table/associations_test.exs`

---

### Phase 10: Migration Helpers

**Objective**: Provide helpers for creating immutable tables.

**Tasks**:
- Create `ImmuTable.Migration` module
- Implement `create_immutable_table/2` macro
- Auto-add required columns with correct types
- Generate recommended indexes:
  - Primary key on `id`
  - Index on `entity_id`
  - Composite index on `(entity_id, version)` for current lookups
  - Index on `valid_from` for temporal queries
- Implement `add_immutable_columns/0` for converting existing tables

**Tests**:
- Migration creates correct columns
- Migration creates correct indexes
- Conversion helper adds columns to existing table

**Files**:
- `lib/immu_table/migration.ex`
- `test/immu_table/migration_test.exs`

---

## Module Structure

```
lib/
  immu_table.ex              # Main module, public API
  immu_table/
    application.ex              # Supervisor
    schema.ex                   # use macro, immutable_schema
    operations.ex               # insert, update, delete, undelete
    query.ex                    # current, history, at_time helpers
    lock.ex                     # Advisory lock helpers
    changeset.ex                # Changeset helpers, field protection
    associations.ex             # immutable_belongs_to, preload helpers
    migration.ex                # Migration helpers
    exceptions.ex               # ImmutableViolationError

test/
  immu_table/
    schema_test.exs
    operations_test.exs
    query_test.exs
    lock_test.exs
    blocking_test.exs
    associations_test.exs
    migration_test.exs
    uuid_test.exs
  support/
    data_case.ex                # Test case with sandbox
    test_repo.ex                # Test repository
    test_schemas.ex             # Test schema definitions
    migrations/                 # Test migrations

priv/
  test_repo/
    migrations/                 # Migrations for test database
```

---

## Dependencies

### Runtime
- `ecto_sql` ~> 3.10

### Development/Test
- `postgrex` ~> 0.17

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

1. All tests pass
2. No modifications to existing rows during update/delete operations
3. Correct current row resolution after delete/undelete cycles
4. Concurrent operations serialize correctly
5. Clear error messages when blocking direct modifications
6. Associations resolve to current versions
7. Query helpers compose with standard Ecto queries
