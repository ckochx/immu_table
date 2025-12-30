# Generator Commands Used

This document tracks all Phoenix generator commands used to create this demo app.

## Initial Setup

```bash
# Generate Phoenix app (from immu_table root directory)
mix phx.new demo --no-mailer --no-dashboard --no-gettext --binary-id

# Add immu_table dependency to mix.exs:
# {:immu_table, path: ".."}

# Install dependencies
cd demo && mix deps.get

# Create database
mix ecto.create
```

## Schema and LiveView Generation

```bash
# Generate LiveView CRUD for Tasks
mix phx.gen.live Tasks Task tasks title:string description:text status:string priority:integer due_date:date

# Run migrations
mix ecto.migrate
```

## Post-Generation Modifications

After running generators, the following files were modified to use ImmuTable:

### 1. Migration (`priv/repo/migrations/*_create_tasks.exs`)

Changed from standard `create table` to `create_immutable_table`:

```elixir
# Before (generated)
create table(:tasks, primary_key: false) do
  add :id, :binary_id, primary_key: true
  # ...
  timestamps(type: :utc_datetime)
end

# After (ImmuTable)
import ImmuTable.Migration

create_immutable_table :tasks do
  add :title, :string, null: false
  # ... (no timestamps - ImmuTable handles valid_from)
end
```

### 2. Schema (`lib/demo/tasks/task.ex`)

Changed to use `immutable_schema`:

```elixir
# Before (generated)
use Ecto.Schema
schema "tasks" do
  # ...
  timestamps()
end

# After (ImmuTable)
use Ecto.Schema
use ImmuTable
import Ecto.Changeset, except: [cast: 3]

immutable_schema "tasks" do
  # ... (no timestamps - ImmuTable injects metadata fields)
end

def changeset(task, attrs) do
  task
  |> cast(attrs, [...])
  |> validate_required([...])
  |> maybe_block_updates(__MODULE__)
  |> maybe_block_deletes(__MODULE__)
end
```

### 3. Context (`lib/demo/tasks.ex`)

Changed all CRUD operations to use ImmuTable:

| Standard Ecto | ImmuTable |
|--------------|-----------|
| `Repo.all(Task)` | `Task \|> ImmuTable.Query.get_current() \|> Repo.all()` |
| `Repo.get!(Task, id)` | `ImmuTable.get!(Task, Repo, entity_id)` |
| `Repo.insert(changeset)` | `ImmuTable.insert(Repo, changeset)` |
| `Repo.update(changeset)` | `changeset \|> ImmuTable.update(Repo)` |
| `Repo.delete(struct)` | `ImmuTable.delete(Repo, struct)` |

Added new functions:
- `get_task_history/1` - Returns all versions
- `undelete_task/2` - Restores deleted tasks

### 4. Router (`lib/demo_web/router.ex`)

Changed route parameter from `:id` to `:entity_id`:

```elixir
# Routes use entity_id for stable URLs across versions
live "/tasks/:entity_id", TaskLive.Show, :show
live "/tasks/:entity_id/edit", TaskLive.Form, :edit
live "/tasks/:entity_id/history", TaskLive.History, :history
```

### 5. LiveViews

All LiveViews updated to:
- Use `entity_id` in params instead of `id`
- Use `task.entity_id` in URLs instead of `task` or `task.id`
- Display version information
- Show immutable metadata

### 6. New Files Created

- `lib/demo_web/live/task_live/history.ex` - Version history timeline view

## Running the Demo

```bash
cd demo

# Start PostgreSQL (if using docker-compose from parent)
docker compose -f ../docker-compose.yml up -d

# Setup and run
mix setup
mix phx.server

# Visit http://localhost:4000/tasks
```

## Key ImmuTable Concepts Demonstrated

1. **Version Numbers**: Each change increments the version
2. **Entity ID**: Stable identifier across all versions (used in URLs)
3. **Row ID**: Unique per version (different for each update)
4. **Soft Deletes**: Creates tombstone version, preserves all history
5. **Undelete**: Restores from tombstone by creating new version
6. **History View**: Complete audit trail of all changes
