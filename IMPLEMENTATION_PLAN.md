# ImmuTable Implementation Plan

## Status

**Last Updated**: 2025-12-30

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
| Phase 11: Mix Generators | ✅ Complete | Schema, context, and migration generators with tests |
| Phase 12: Enhanced Generators | 🔄 In Progress | Phase 12.0 complete; HTML & LiveView generators planned |
| **Demo App** | ✅ Complete | Phoenix LiveView CRUD app demonstrating all features |

---

## Latest Updates (2025-12-30)

### Mix Generators

Added code generators for scaffolding ImmuTable schemas, contexts, and migrations:

```bash
# Generate a schema with immutable_schema
$ mix immutable.gen.schema Blog.Post posts title:string body:text

# Generate a migration with create_immutable_table
$ mix immutable.gen.migration Blog.Post posts title:string body:text

# Generate context + schema (like phx.gen.context)
$ mix immutable.gen.context Blog Post posts title:string body:text
```

Features:
- Generates proper `immutable_schema` with field definitions
- Creates changesets that use the module's `cast/3` (not `Ecto.Changeset.cast/3`)
- Migrations use `create_immutable_table` with correct indexes
- Contexts include all ImmuTable operations (list, get, create, update, delete, undelete, history)
- References automatically use `entity_id` foreign keys

---

## Phase 12: Enhanced Generators (Planned)

Goal: Align ImmuTable generators with Phoenix conventions and add HTML/LiveView generators.

### Phase 12.0: Suppress Row ID ✅ Complete

The `id` field is a row-level implementation detail that changes with each version. Users should interact with `entity_id` (stable across versions). Previously `id` leaked to users via:
- `IO.inspect` output and logs
- Demo app UI (metadata sections)
- LiveView streams use `id` by default for DOM element IDs

**Design Decision: Hide `id` from Inspect by Default**

| Field | Purpose | User-Facing? |
|-------|---------|--------------|
| `id` | Row primary key (changes per version) | No - internal |
| `entity_id` | Stable entity identifier | Yes - use everywhere |

**Implementation:**

1. **Add `show_row_id` option** (default `false`):
   ```elixir
   use ImmuTable, show_row_id: false  # default - hide id from inspect
   use ImmuTable, show_row_id: true   # for debugging
   ```

2. **Schema changes** (`lib/immu_table/schema.ex`):
   - When `show_row_id: false`, inject `@derive {Inspect, except: [:id]}`
   - Add `__immutable__(:show_row_id)` accessor

3. **Generator templates** use `entity_id` for DOM IDs:
   ```elixir
   # In LiveView templates
   stream(socket, :tasks, tasks, dom_id: fn t -> "task-#{t.entity_id}" end)
   ```

4. **Demo app cleanup**:
   - Remove `id` display from Show pages
   - Remove `id` from History timeline
   - Update streams to use `entity_id` for DOM IDs

**Why not rename `id` to `_row_id`?**
- Breaking change for existing users
- May confuse Ecto internals that expect `:id` primary key
- Hiding from Inspect achieves the goal without breaking changes

**LiveView Stream Compatibility:**

LiveView's `stream/3` uses `id` by default, but supports `:dom_id` option:
```elixir
# Default (uses id)
stream(socket, :tasks, tasks)

# ImmuTable recommended (uses entity_id)
stream(socket, :tasks, tasks, dom_id: fn t -> "task-#{t.entity_id}" end)
```

This keeps `id` available internally while hiding it from users and logs.

---

### Comparison: Current State vs Phoenix

| Feature | ImmuTable | Phoenix |
|---------|-----------|---------|
| **Templates** | Embedded in module (`~S"""`) | External files in `priv/templates/` |
| **Helper Structs** | Custom functions in Generator | `Mix.Phoenix.Schema`, `Mix.Phoenix.Context` structs |
| **Test Generation** | ❌ None | ✅ Context tests + fixtures |
| **Template Customization** | ❌ Not supported | ✅ Project-local overrides |
| **CLI Options** | Minimal | Rich (`--no-migration`, `--binary-id`, etc.) |
| **HTML Generator** | ❌ Missing | ✅ `phx.gen.html` |
| **LiveView Generator** | ❌ Missing | ✅ `phx.gen.live` |

### Phase 12.1: Refactor Template System

Move from embedded templates to external files like Phoenix.

**Changes:**
- Create `priv/templates/immutable.gen.schema/schema.ex`
- Create `priv/templates/immutable.gen.migration/migration.exs`
- Create `priv/templates/immutable.gen.context/context.ex`, `schema_access.ex`
- Update generators to use `Mix.Generator.copy_from/4` with template directories
- Add fallback to embedded templates for library use (when priv not available)

### Phase 12.2: Create Schema Struct

Structured metadata like `Mix.Phoenix.Schema`.

**Create `lib/mix/immutable/schema.ex`:**
```elixir
defstruct [
  :module, :table, :repo, :singular, :plural,
  :human_singular, :human_plural, :attrs, :types,
  :uniques, :migration?, :context_module, :context_alias,
  # ImmuTable-specific
  :entity_id_type, :version_field?
]
```

### Phase 12.3: Add Test & Fixture Generation

Generate context tests and fixtures like Phoenix.

**Add to `immutable.gen.context`:**
- `test/<app>/<context>_test.exs` - Context test file
- `test/support/fixtures/<context>_fixtures.ex` - Test data fixtures

**ImmuTable-specific test cases:**
- Version creation tests
- History retrieval tests
- Soft delete/undelete tests

### Phase 12.4: Add `immutable.gen.html`

Generate controller + HTML views for ImmuTable schemas.

**Files to generate:**
- `lib/<app>_web/controllers/<resource>_controller.ex`
- `lib/<app>_web/controllers/<resource>_html.ex`
- `lib/<app>_web/controllers/<resource>_html/`
  - `index.html.heex`
  - `show.html.heex` (with history timeline)
  - `new.html.heex`
  - `edit.html.heex`
  - `<resource>_form.html.heex`
  - `history.html.heex` (ImmuTable-specific)
- `test/<app>_web/controllers/<resource>_controller_test.exs`

**ImmuTable-specific features:**
- History view showing all versions
- Soft delete with restore option
- Routes use `entity_id` not `id`
- "Deleted" badge for tombstoned records

### Phase 12.5: Add `immutable.gen.live`

Generate LiveView modules for ImmuTable schemas.

**Files to generate:**
- `lib/<app>_web/live/<resource>_live/index.ex`
- `lib/<app>_web/live/<resource>_live/show.ex` (with history stream)
- `lib/<app>_web/live/<resource>_live/form.ex`
- `test/<app>_web/live/<resource>_live_test.exs`

**ImmuTable-specific features:**
- History timeline component
- Real-time version updates
- Soft delete/undelete actions
- "Show deleted" toggle
- Point-in-time view option

### Phase 12.6: Add CLI Options

Feature parity with Phoenix options.

**Add options:**
- `--no-migration` - Skip migration generation
- `--no-schema` - Skip schema (use existing)
- `--no-context` - Skip context (use existing)
- `--no-tests` - Skip test generation
- `--table NAME` - Custom table name
- `--context-app APP` - For umbrella apps
- `--web NAMESPACE` - Web namespace

### Target File Structure

```
lib/mix/
├── immutable/
│   ├── generator.ex        # Utilities (existing, enhanced)
│   ├── schema.ex           # NEW: Schema struct
│   └── templates.ex        # Keep for fallback
└── tasks/
    ├── immutable.gen.schema.ex      # Existing, refactored
    ├── immutable.gen.migration.ex   # Existing, refactored
    ├── immutable.gen.context.ex     # Existing, refactored
    ├── immutable.gen.html.ex        # NEW
    └── immutable.gen.live.ex        # NEW

priv/templates/
├── immutable.gen.schema/
│   └── schema.ex
├── immutable.gen.migration/
│   └── migration.exs
├── immutable.gen.context/
│   ├── context.ex
│   ├── context_test.exs
│   └── fixtures.ex
├── immutable.gen.html/
│   ├── controller.ex
│   ├── html.ex
│   ├── index.html.heex
│   ├── show.html.heex
│   ├── new.html.heex
│   ├── edit.html.heex
│   ├── resource_form.html.heex
│   ├── history.html.heex
│   └── controller_test.exs
└── immutable.gen.live/
    ├── index.ex
    ├── show.ex
    ├── form.ex
    └── live_test.exs
```

### Implementation Priority

1. **Phase 12.0** (Suppress Row ID) - Core schema change, prerequisite for generators
2. **Phase 12.2** (Schema struct) - Foundation for generator changes
3. **Phase 12.1** (External templates) - Required for customization
4. **Phase 12.5** (LiveView generator) - High value, builds on demo work
5. **Phase 12.4** (HTML generator) - Alternative to LiveView
6. **Phase 12.3** (Test generation) - Quality improvement
7. **Phase 12.6** (CLI options) - Polish

---

## Previous Updates (2025-12-29)

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

**250 tests, 0 failures**

---

## Summary

### Completed Phases
All 11 implementation phases are now complete:
- ✅ Phase 1-8: Core functionality (insert, update, delete, undelete, queries, blocking)
- ✅ Phase 9: Association support (belongs_to, has_many, has_one with batch preloading)
- ✅ Phase 10: Migration helpers (create_immutable_table, add_immutable_indexes)
- ✅ Phase 11: Mix generators (schema, context, migration)
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
- ✅ Hex package configuration (`mix hex.build`)
- ✅ ExDoc configuration (`mix docs`)
- ✅ Mix generators (schema, context, migration)

### Remaining Work (LOW Priority)
- Typespecs for public API
- Ecto.Multi integration docs
- Batch operations (insert_all, update_all)
- Hardcoded timestamp source
- Full Ecto integration for associations (cast_assoc, Repo.preload)

### Future Enhancement
- **Phase 12: Enhanced Generators** - See detailed plan above
  - HTML and LiveView generators with ImmuTable-aware templates
  - External template system with customization support
  - Test and fixture generation

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
  mix/
    immutable/
      generator.ex           # Generator utilities
      templates.ex           # EEx templates
    tasks/
      immutable.gen.schema.ex    # Schema generator
      immutable.gen.migration.ex # Migration generator
      immutable.gen.context.ex   # Context generator

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
  mix/tasks/
    immutable.gen.schema_test.exs
    immutable.gen.migration_test.exs
    immutable.gen.context_test.exs
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

1. ✅ All tests pass (250 tests)
2. ✅ No modifications to existing rows during update/delete operations
3. ✅ Correct current row resolution after delete/undelete cycles
4. ✅ Concurrent operations serialize correctly
5. ✅ Clear error messages when blocking direct modifications
6. ✅ Associations resolve to current versions
7. ✅ Query helpers compose with standard Ecto queries
8. ✅ Demo app demonstrates all features
