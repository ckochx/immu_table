defmodule Demo.TasksFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Demo.Tasks` context.
  """

  @doc """
  Generate a task.
  """
  def task_fixture(attrs \\ %{}) do
    {:ok, task} =
      attrs
      |> Enum.into(%{
        description: "some description",
        due_date: ~D[2025-12-29],
        priority: 42,
        status: "some status",
        title: "some title"
      })
      |> Demo.Tasks.create_task()

    task
  end
end
