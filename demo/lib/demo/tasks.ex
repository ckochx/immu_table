defmodule Demo.Tasks do
  @moduledoc """
  The Tasks context.

  This module demonstrates using ImmuTable for immutable, versioned data.
  All changes create new versions rather than modifying existing rows.
  """

  import Ecto.Query

  alias Demo.Repo
  alias Demo.Tasks.Task
  alias Demo.Tasks.Assignee

  @doc """
  Returns the list of current (non-deleted) tasks.
  """
  def list_tasks do
    Task
    |> ImmuTable.Query.get_current()
    |> Repo.all()
  end

  @doc """
  Returns the list of all tasks including deleted ones.
  """
  def list_tasks_with_deleted do
    Task
    |> ImmuTable.Query.include_deleted()
    |> Repo.all()
  end

  @doc """
  Returns only deleted (tombstoned) tasks.
  """
  def list_deleted_tasks do
    Task
    |> ImmuTable.Query.include_deleted()
    |> where([t], not is_nil(t.deleted_at))
    |> Repo.all()
  end

  @doc """
  Gets a single task by entity_id.

  Raises `Ecto.NoResultsError` if the Task does not exist or is deleted.
  """
  def get_task!(entity_id) do
    ImmuTable.get!(Task, Repo, entity_id)
  end

  @doc """
  Gets a single task by entity_id, returning nil if not found or deleted.
  """
  def get_task(entity_id) do
    ImmuTable.get(Task, Repo, entity_id)
  end

  @doc """
  Gets a task with detailed status information.

  Returns `{:ok, task}`, `{:error, :deleted}`, or `{:error, :not_found}`.
  """
  def fetch_task(entity_id) do
    ImmuTable.fetch_current(Task, Repo, entity_id)
  end

  @doc """
  Returns the complete version history for a task.
  """
  def get_task_history(entity_id) do
    Task
    |> ImmuTable.Query.history(entity_id)
    |> Repo.all()
  end

  @doc """
  Creates a task (version 1).
  """
  def create_task(attrs) do
    changeset = Task.changeset(%Task{}, attrs)
    ImmuTable.insert(Repo, changeset)
  end

  @doc """
  Updates a task by creating a new version.

  The previous version remains unchanged in the database.
  """
  def update_task(%Task{} = task, attrs) do
    task
    |> Task.changeset(attrs)
    |> ImmuTable.update(Repo)
  end

  @doc """
  Soft-deletes a task by creating a tombstone version.

  The task and all its history remain in the database.
  """
  def delete_task(%Task{} = task) do
    ImmuTable.delete(Repo, task)
  end

  @doc """
  Restores a deleted task by creating a new active version.
  """
  def undelete_task(%Task{} = task, attrs \\ %{}) do
    ImmuTable.undelete(Repo, task, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking task changes.
  """
  def change_task(%Task{} = task, attrs \\ %{}) do
    Task.changeset(task, attrs)
  end

  @doc """
  Searches tasks by assignee name.

  This demonstrates ImmuTable.Query.current/2 with named bindings for
  joining ImmuTable-managed entities with regular Ecto schemas.

  Uses named bindings which makes the query readable and maintainable:
  - [task: t] refers to the task
  - [assignee: a] refers to the assignee
  """
  def search_tasks_by_assignee(name_pattern) do
    pattern = "%#{name_pattern}%"

    Task
    |> ImmuTable.Query.current(as: :task)
    |> join(:inner, [task: t], a in Assignee, on: t.entity_id == a.task_entity_id, as: :assignee)
    |> where([task: t, assignee: a], ilike(a.name, ^pattern))
    |> select([task: t, assignee: a], %{task: t, assignee_name: a.name})
    |> Repo.all()
  end

  @doc """
  Lists all tasks with their assignees (if any).

  Demonstrates a left join where tasks may or may not have assignees.
  """
  def list_tasks_with_assignees do
    Task
    |> ImmuTable.Query.current(as: :task)
    |> join(:left, [task: t], a in Assignee, on: t.entity_id == a.task_entity_id, as: :assignee)
    |> select([task: t, assignee: a], %{task: t, assignee: a})
    |> Repo.all()
  end

  @doc """
  Gets all assignees for a task.
  """
  def list_assignees_for_task(task_entity_id) do
    Assignee
    |> where([a], a.task_entity_id == ^task_entity_id)
    |> Repo.all()
  end

  @doc """
  Creates an assignee for a task.
  """
  def create_assignee(attrs) do
    %Assignee{}
    |> Assignee.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes an assignee.
  """
  def delete_assignee(%Assignee{} = assignee) do
    Repo.delete(assignee)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking assignee changes.
  """
  def change_assignee(%Assignee{} = assignee, attrs \\ %{}) do
    Assignee.changeset(assignee, attrs)
  end
end
