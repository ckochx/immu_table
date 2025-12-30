defmodule Demo.TasksTest do
  use Demo.DataCase

  alias Demo.Tasks

  describe "tasks" do
    alias Demo.Tasks.Task

    import Demo.TasksFixtures

    @invalid_attrs %{priority: nil, status: nil, description: nil, title: nil, due_date: nil}

    test "list_tasks/0 returns all tasks" do
      task = task_fixture()
      assert Tasks.list_tasks() == [task]
    end

    test "get_task!/1 returns the task with given id" do
      task = task_fixture()
      assert Tasks.get_task!(task.id) == task
    end

    test "create_task/1 with valid data creates a task" do
      valid_attrs = %{priority: 42, status: "some status", description: "some description", title: "some title", due_date: ~D[2025-12-29]}

      assert {:ok, %Task{} = task} = Tasks.create_task(valid_attrs)
      assert task.priority == 42
      assert task.status == "some status"
      assert task.description == "some description"
      assert task.title == "some title"
      assert task.due_date == ~D[2025-12-29]
    end

    test "create_task/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Tasks.create_task(@invalid_attrs)
    end

    test "update_task/2 with valid data updates the task" do
      task = task_fixture()
      update_attrs = %{priority: 43, status: "some updated status", description: "some updated description", title: "some updated title", due_date: ~D[2025-12-30]}

      assert {:ok, %Task{} = task} = Tasks.update_task(task, update_attrs)
      assert task.priority == 43
      assert task.status == "some updated status"
      assert task.description == "some updated description"
      assert task.title == "some updated title"
      assert task.due_date == ~D[2025-12-30]
    end

    test "update_task/2 with invalid data returns error changeset" do
      task = task_fixture()
      assert {:error, %Ecto.Changeset{}} = Tasks.update_task(task, @invalid_attrs)
      assert task == Tasks.get_task!(task.id)
    end

    test "delete_task/1 deletes the task" do
      task = task_fixture()
      assert {:ok, %Task{}} = Tasks.delete_task(task)
      assert_raise Ecto.NoResultsError, fn -> Tasks.get_task!(task.id) end
    end

    test "change_task/1 returns a task changeset" do
      task = task_fixture()
      assert %Ecto.Changeset{} = Tasks.change_task(task)
    end
  end
end
