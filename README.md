# ImmuTable

Append-only (immutable) tables with version tracking for Ecto.

UPDATE and DELETE operations destroy history. Immutable tables preserve it by inserting new versions instead of modifying rows. This enables audit trails, point-in-time queries, and eliminates lost update problems.

## Installation

```elixir
def deps do
  [
    {:immu_table, "~> 0.1.0"}
  ]
end
```

### Requirements

- Elixir ~> 1.14
- Ecto SQL ~> 3.10
- PostgreSQL (required for advisory locks and UUIDv7)

## Generators

ImmuTable includes Mix generators to scaffold schemas, contexts, and migrations:

```bash
# Generate a schema with immutable_schema
$ mix immutable.gen.schema Blog.Post posts title:string body:text

# Generate a migration with create_immutable_table
$ mix immutable.gen.migration Blog.Post posts title:string body:text

# Generate context + schema (like phx.gen.context)
$ mix immutable.gen.context Blog Post posts title:string body:text
```

The context generator creates a complete context module with all ImmuTable operations:
- `list_posts/0` - List current records
- `get_post!/1` and `get_post/1` - Get by entity_id
- `create_post/1` - Create version 1
- `update_post/2` - Create new version
- `delete_post/1` - Create tombstone
- `undelete_post/1` - Restore from tombstone
- `get_post_history/1` - Get all versions

## Quick Start

### 1. Create a Migration

Use `create_immutable_table` instead of `create table`:

```elixir
defmodule MyApp.Repo.Migrations.CreateTasks do
  use Ecto.Migration
  import ImmuTable.Migration

  def change do
    create_immutable_table :tasks do
      add :title, :string, null: false
      add :description, :text
      add :status, :string, default: "pending"
    end
  end
end
```

This creates a table with these additional columns:
- `id` - unique identifier for this specific version (UUIDv7)
- `entity_id` - stable identifier across all versions (UUIDv7)
- `version` - incrementing version number (1, 2, 3...)
- `valid_from` - timestamp when this version was created
- `deleted_at` - timestamp when soft-deleted (nil if active)

### 2. Define the Schema

```elixir
defmodule MyApp.Tasks.Task do
  use Ecto.Schema
  use ImmuTable

  import Ecto.Changeset, except: [cast: 3]

  immutable_schema "tasks" do
    field :title, :string
    field :description, :string
    field :status, :string
  end

  def changeset(task, attrs \\ %{}) do
    task
    |> cast(attrs, [:title, :description, :status])
    |> validate_required([:title])
  end
end
```

Key differences from standard Ecto schemas:
- `use ImmuTable` - enables immutable table macros
- `import Ecto.Changeset, except: [cast: 3]` - use ImmuTable's cast which filters protected fields
- `immutable_schema` instead of `schema` - injects metadata fields automatically
- No `timestamps()` - ImmuTable uses `valid_from` instead

### 3. Create a Context Module

```elixir
defmodule MyApp.Tasks do
  alias MyApp.Repo
  alias MyApp.Tasks.Task

  def list_tasks do
    Task
    |> ImmuTable.Query.get_current()
    |> Repo.all()
  end

  def get_task!(entity_id) do
    ImmuTable.get!(Task, Repo, entity_id)
  end

  def get_task(entity_id) do
    ImmuTable.get(Task, Repo, entity_id)
  end

  def create_task(attrs) do
    changeset = Task.changeset(%Task{}, attrs)
    ImmuTable.insert(Repo, changeset)
  end

  def update_task(%Task{} = task, attrs) do
    task
    |> Task.changeset(attrs)
    |> ImmuTable.update(Repo)
  end

  def delete_task(%Task{} = task) do
    ImmuTable.delete(Repo, task)
  end

  def get_task_history(entity_id) do
    Task
    |> ImmuTable.Query.history(entity_id)
    |> Repo.all()
  end

  def undelete_task(%Task{} = task) do
    ImmuTable.undelete(Repo, task)
  end
end
```

## API Reference

### CRUD Operations

| Function | Description |
|----------|-------------|
| `ImmuTable.insert(Repo, struct_or_changeset)` | Create version 1 of a new entity |
| `ImmuTable.update(Repo, struct, changes)` | Create new version with changes |
| `ImmuTable.update(Repo, changeset)` | Create new version from changeset (pipe-friendly) |
| `ImmuTable.delete(Repo, struct)` | Create tombstone version (soft delete) |
| `ImmuTable.undelete(Repo, struct)` | Restore from tombstone |

### Query Functions

| Function | Description |
|----------|-------------|
| `ImmuTable.get(Schema, Repo, entity_id)` | Get current version or nil |
| `ImmuTable.get!(Schema, Repo, entity_id)` | Get current version or raise |
| `ImmuTable.fetch_current(Schema, Repo, entity_id)` | Get with status: `{:ok, record}`, `{:error, :deleted}`, or `{:error, :not_found}` |

### Query Helpers

```elixir
# Current (non-deleted) versions only
Task |> ImmuTable.Query.get_current() |> Repo.all()

# Include deleted (tombstoned) records
Task |> ImmuTable.Query.include_deleted() |> Repo.all()

# All versions of a specific entity
Task |> ImmuTable.Query.history(entity_id) |> Repo.all()

# Point-in-time query
Task |> ImmuTable.Query.at_time(~U[2024-01-15 10:00:00Z]) |> Repo.all()

# All versions (no filtering)
Task |> ImmuTable.Query.all_versions() |> Repo.all()
```

## How It Works

### Version Creation

Every change creates a new row:

```
| id   | entity_id | version | title      | deleted_at |
|------|-----------|---------|------------|------------|
| uuid1| abc123    | 1       | "Draft"    | nil        |  <- insert
| uuid2| abc123    | 2       | "Final"    | nil        |  <- update
| uuid3| abc123    | 3       | "Final"    | 2024-01-20 |  <- delete (tombstone)
| uuid4| abc123    | 4       | "Restored" | nil        |  <- undelete
```

### Entity ID vs Row ID

- `entity_id` - Stable identifier. Use this in URLs and foreign keys.
- `id` - Unique per version. Changes with every update.

### Soft Deletes

Deleting creates a tombstone row with `deleted_at` set. The entity and all its history remain in the database. Use `undelete/2` to restore.

## Phoenix LiveView Integration

Routes should use `entity_id` for stable URLs:

```elixir
live "/tasks/:entity_id", TaskLive.Show, :show
live "/tasks/:entity_id/edit", TaskLive.Form, :edit
```

See the `demo/` folder for a complete Phoenix LiveView example with:
- CRUD operations
- Version history timeline
- Soft delete with restore
- Tombstone view

## Options

Configure behavior per-schema:

```elixir
use ImmuTable, allow_updates: true   # Permit Repo.update (bypasses immutability)
use ImmuTable, allow_deletes: true   # Permit Repo.delete (bypasses immutability)
```

By default, direct `Repo.update` and `Repo.delete` calls raise `ImmutableViolationError`.
