# ImmuTableEx Implementation Plan

## Status

**Last Updated**: 2025-12-02

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Project Setup | ✅ Complete | All dependencies installed, project compiles without warnings |
| Phase 2: Schema Macro & Field Injection | ✅ Complete | All fields injected, changeset filtering working, options stored |
| Phase 3: Insert Operations | 🔜 Next | - |
| Phase 4: Update Operations | ⏳ Pending | - |
| Phase 5: Delete Operations | ⏳ Pending | - |
| Phase 6: Undelete Operations | ⏳ Pending | - |
| Phase 7: Query Helpers | ⏳ Pending | - |
| Phase 8: Blocking Repo.update/delete | ⏳ Pending | - |
| Phase 9: Association Support | ⏳ Pending | - |
| Phase 10: Migration Helpers | ⏳ Pending | - |
| Phase 11: Custom UUIDv7 Implementation | ⏳ Pending | - |

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
- `lib/immu_table_ex/application.ex` - Supervisor with TestRepo in test env
- `test/support/test_repo.ex` - Test repository
- `test/support/data_case.ex` - Test case template with sandbox
- Stub modules: `schema.ex`, `operations.ex`, `query.ex`, `lock.ex`, `changeset.ex`, `associations.ex`, `migration.ex`, `exceptions.ex`

---

### Phase 2 Completion Details

**Completed**: 2025-12-02

✅ Implemented `use ImmuTableEx` macro with options parsing
✅ Created `immutable_schema/2` macro wrapping `Ecto.Schema.schema/2`
✅ Injected required fields: `entity_id`, `version`, `valid_from`, `deleted_at`
✅ Configured UUIDv7 as primary key type
✅ Implemented changeset filtering via custom `cast/3` function
✅ Stored options in module attributes accessible via `__immutable__/1`

**Files Implemented**:
- `lib/immu_table_ex.ex` - `__using__/1` macro
- `lib/immu_table_ex/schema.ex` - `immutable_schema/2` macro, `__before_compile__/1` callback
- `test/support/test_schemas.ex` - Test schemas with various configurations
- `test/immu_table_ex/schema_test.exs` - Comprehensive tests (12 tests, all passing)
- `docker-compose.yml` - PostgreSQL test database configuration

**Test Results**: 13/13 tests passing, compiles without warnings

---

## Overview

ImmuTableEx is an Elixir library that makes Ecto tables immutable. Instead of updating or deleting rows, new rows are inserted with version tracking metadata. This provides a complete audit trail and enables point-in-time queries.

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
use ImmuTableEx, allow_updates: true
use ImmuTableEx, allow_deletes: true
```

---

## Target API

```elixir
defmodule MyApp.Account do
  use Ecto.Schema
  use ImmuTableEx

  immutable_schema "accounts" do
    field :name, :string
    field :balance, :decimal

    immutable_belongs_to :user, MyApp.User
  end
end

# Insert
{:ok, account} = ImmuTableEx.insert(Repo, %Account{name: "Checking", balance: 100})
# => %Account{id: <uuid>, entity_id: <uuid>, version: 1, ...}

# Update (creates new version)
{:ok, updated} = ImmuTableEx.update(Repo, account, %{balance: 150})
# => %Account{id: <new-uuid>, entity_id: <same-uuid>, version: 2, ...}

# Delete (creates tombstone)
{:ok, deleted} = ImmuTableEx.delete(Repo, account)
# => %Account{..., version: 3, deleted_at: ~U[...]}

# Undelete
{:ok, restored} = ImmuTableEx.undelete(Repo, deleted)
# => %Account{..., version: 4, deleted_at: nil}

# Query current versions
Account |> ImmuTableEx.current() |> Repo.all()

# Query history
Account |> ImmuTableEx.history(entity_id) |> Repo.all()

# Query at point in time
Account |> ImmuTableEx.at_time(~U[2024-01-15 10:00:00Z]) |> Repo.all()
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
- `lib/immu_table_ex.ex`
- `lib/immu_table_ex/application.ex`
- `config/config.exs`
- `config/test.exs`

---

### Phase 2: Schema Macro & Field Injection

**Objective**: Implement `use ImmuTableEx` macro that injects required fields.

**Tasks**:
- Create `ImmuTableEx.Schema` module
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
- `lib/immu_table_ex/schema.ex`
- `test/immu_table_ex/schema_test.exs`
- `test/support/test_schemas.ex`

---

### Phase 3: Insert Operations

**Objective**: Implement insert that auto-generates immutability metadata.

**Tasks**:
- Create `ImmuTableEx.Operations` module
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
- `lib/immu_table_ex/operations.ex`
- `test/immu_table_ex/operations_test.exs`

---

### Phase 4: Update Operations (Versioned Insert)

**Objective**: Implement update that creates a new version row.

**Tasks**:
- Implement `update/3` and `update!/3`
- Create `ImmuTableEx.Lock` module for advisory locks
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
- `lib/immu_table_ex/operations.ex` (extend)
- `lib/immu_table_ex/lock.ex`
- `test/immu_table_ex/lock_test.exs`
- `test/immu_table_ex/operations_test.exs` (extend)

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
- `lib/immu_table_ex/operations.ex` (extend)
- `test/immu_table_ex/operations_test.exs` (extend)

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
- `lib/immu_table_ex/operations.ex` (extend)
- `test/immu_table_ex/operations_test.exs` (extend)

---

### Phase 7: Query Helpers

**Objective**: Implement query composable functions for immutable tables.

**Tasks**:
- Create `ImmuTableEx.Query` module
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
- `lib/immu_table_ex/query.ex`
- `test/immu_table_ex/query_test.exs`

---

### Phase 8: Blocking Repo.update/delete

**Objective**: Prevent direct Repo operations on immutable schemas.

**Tasks**:
- Create `ImmuTableEx.Changeset` module
- Implement blocking via `Ecto.Changeset.prepare_changes/2`
- Store `__immutable__` metadata in schema
- Create `ImmuTableEx.ImmutableViolationError` exception
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
- `lib/immu_table_ex/changeset.ex`
- `lib/immu_table_ex/exceptions.ex`
- `test/immu_table_ex/blocking_test.exs`

---

### Phase 9: Association Support

**Objective**: Implement immutable-aware associations.

**Tasks**:
- Create `ImmuTableEx.Associations` module
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
- `lib/immu_table_ex/associations.ex`
- `test/immu_table_ex/associations_test.exs`

---

### Phase 10: Migration Helpers

**Objective**: Provide helpers for creating immutable tables.

**Tasks**:
- Create `ImmuTableEx.Migration` module
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
- `lib/immu_table_ex/migration.ex`
- `test/immu_table_ex/migration_test.exs`

---

### Phase 11: Custom UUIDv7 Implementation

**Objective**: Replace `uuidv7` dependency with minimal internal implementation.

**Tasks**:
- Create `ImmuTableEx.UUID` module
- Implement UUIDv7 generation per RFC 9562
- Use millisecond timestamp + random bits
- Ensure monotonicity within same millisecond (counter or random)
- Implement binary and string formatting
- Remove `uuidv7` hex dependency

**Tests**:
- Generated UUIDs are valid v7 format
- UUIDs are time-sortable
- UUIDs generated in same millisecond maintain ordering or uniqueness
- Uniqueness under concurrent generation
- Binary and string formats correct

**Files**:
- `lib/immu_table_ex/uuid.ex`
- `test/immu_table_ex/uuid_test.exs`
- `mix.exs` (remove dependency)

---

## Module Structure

```
lib/
  immu_table_ex.ex              # Main module, public API
  immu_table_ex/
    application.ex              # Supervisor
    schema.ex                   # use macro, immutable_schema
    operations.ex               # insert, update, delete, undelete
    query.ex                    # current, history, at_time helpers
    lock.ex                     # Advisory lock helpers
    changeset.ex                # Changeset helpers, field protection
    associations.ex             # immutable_belongs_to, preload helpers
    migration.ex                # Migration helpers
    exceptions.ex               # ImmutableViolationError
    uuid.ex                     # UUIDv7 implementation (Phase 11)

test/
  immu_table_ex/
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
- `uuidv7` ~> 0.2 (until Phase 11)

---

## Configuration Options

```elixir
use ImmuTableEx,
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
