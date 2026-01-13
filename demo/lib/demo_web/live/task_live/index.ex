defmodule DemoWeb.TaskLive.Index do
  use DemoWeb, :live_view

  alias Demo.Tasks

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Listing Tasks
        <:subtitle>
          All changes create new versions. Nothing is ever truly deleted.
        </:subtitle>
        <:actions>
          <.button navigate={~p"/tasks/deleted"}>
            <.icon name="hero-trash" /> Deleted
          </.button>
          <.button variant="primary" navigate={~p"/tasks/new"}>
            <.icon name="hero-plus" /> New Task
          </.button>
        </:actions>
      </.header>

      <div class="mt-4 mb-6 p-4 bg-gray-50 rounded-lg border">
        <h3 class="text-sm font-medium text-gray-700 mb-2">
          Search by Assignee
          <span class="text-xs text-gray-500">(demonstrates ImmuTable.Query.current/2 with joins)</span>
        </h3>
        <form phx-submit="search" phx-change="search" class="flex gap-2">
          <input
            type="text"
            name="assignee_search"
            value={@assignee_search}
            placeholder="Search by assignee name..."
            class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            phx-debounce="300"
          />
          <button
            type="button"
            phx-click="clear_search"
            class="px-3 py-2 text-sm text-gray-600 hover:text-gray-800"
          >
            Clear
          </button>
        </form>
        <p :if={@assignee_search != ""} class="mt-2 text-sm text-gray-600">
          Found {@search_count} task(s) with assignees matching "{@assignee_search}"
        </p>
      </div>

      <.table
        id="tasks"
        rows={@streams.tasks}
        row_click={fn {_id, task} -> JS.navigate(~p"/tasks/#{task.entity_id}") end}
      >
        <:col :let={{_id, task}} label="Title">{task.title}</:col>
        <:col :let={{_id, task}} label="Status">
          <span class={status_class(task.status)}>{task.status}</span>
        </:col>
        <:col :let={{_id, task}} label="Priority">{task.priority}</:col>
        <:col :let={{_id, task}} label="Assignees">
          <span class="text-sm text-gray-600">
            {format_assignees(Map.get(@assignees_by_task, task.entity_id, []))}
          </span>
        </:col>
        <:col :let={{_id, task}} label="Version">v{task.version}</:col>
        <:action :let={{_id, task}}>
          <.link navigate={~p"/tasks/#{task.entity_id}/history"}>History</.link>
        </:action>
        <:action :let={{_id, task}}>
          <.link navigate={~p"/tasks/#{task.entity_id}/edit"}>Edit</.link>
        </:action>
        <:action :let={{_id, task}}>
          <.link
            phx-click={JS.push("delete", value: %{entity_id: task.entity_id}) |> hide("#tasks-#{task.entity_id}")}
            data-confirm="Are you sure? This will create a tombstone version."
          >
            Delete
          </.link>
        </:action>
      </.table>

      <div class="mt-8 p-4 bg-blue-50 rounded-lg border border-blue-200">
        <h3 class="text-sm font-medium text-blue-800 mb-2">Add Test Assignee</h3>
        <form phx-submit="add_assignee" class="flex gap-2">
          <select name="task_entity_id" class="rounded-md border-gray-300 shadow-sm sm:text-sm">
            <option value="">Select a task...</option>
            <%= for {_id, task} <- @streams.tasks do %>
              <option value={task.entity_id}>{task.title}</option>
            <% end %>
          </select>
          <input
            type="text"
            name="name"
            placeholder="Assignee name"
            class="rounded-md border-gray-300 shadow-sm sm:text-sm"
            required
          />
          <input
            type="email"
            name="email"
            placeholder="Email (optional)"
            class="rounded-md border-gray-300 shadow-sm sm:text-sm"
          />
          <button type="submit" class="px-4 py-2 bg-blue-600 text-white rounded-md text-sm hover:bg-blue-700">
            Add
          </button>
        </form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    tasks = Tasks.list_tasks()
    assignees_by_task = load_assignees_for_tasks(tasks)

    {:ok,
     socket
     |> assign(:page_title, "Listing Tasks")
     |> assign(:assignee_search, "")
     |> assign(:search_count, 0)
     |> assign(:assignees_by_task, assignees_by_task)
     |> stream(:tasks, tasks, dom_id: &"tasks-#{&1.entity_id}")}
  end

  @impl true
  def handle_event("search", %{"assignee_search" => search}, socket) do
    if search == "" do
      tasks = Tasks.list_tasks()
      assignees_by_task = load_assignees_for_tasks(tasks)

      {:noreply,
       socket
       |> assign(:assignee_search, "")
       |> assign(:search_count, 0)
       |> assign(:assignees_by_task, assignees_by_task)
       |> stream(:tasks, tasks, reset: true)}
    else
      results = Tasks.search_tasks_by_assignee(search)
      tasks = Enum.map(results, & &1.task)
      assignees_by_task = load_assignees_for_tasks(tasks)

      {:noreply,
       socket
       |> assign(:assignee_search, search)
       |> assign(:search_count, length(results))
       |> assign(:assignees_by_task, assignees_by_task)
       |> stream(:tasks, tasks, reset: true)}
    end
  end

  def handle_event("clear_search", _params, socket) do
    tasks = Tasks.list_tasks()
    assignees_by_task = load_assignees_for_tasks(tasks)

    {:noreply,
     socket
     |> assign(:assignee_search, "")
     |> assign(:search_count, 0)
     |> assign(:assignees_by_task, assignees_by_task)
     |> stream(:tasks, tasks, reset: true)}
  end

  def handle_event("add_assignee", %{"task_entity_id" => "", "name" => _}, socket) do
    {:noreply, put_flash(socket, :error, "Please select a task")}
  end

  def handle_event("add_assignee", %{"task_entity_id" => task_id, "name" => name, "email" => email}, socket) do
    attrs = %{task_entity_id: task_id, name: name, email: email}

    case Tasks.create_assignee(attrs) do
      {:ok, _assignee} ->
        tasks = Tasks.list_tasks()
        assignees_by_task = load_assignees_for_tasks(tasks)

        {:noreply,
         socket
         |> put_flash(:info, "Assignee added successfully")
         |> assign(:assignees_by_task, assignees_by_task)}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(changeset.errors)}")}
    end
  end

  def handle_event("delete", %{"entity_id" => entity_id}, socket) do
    task = Tasks.get_task!(entity_id)
    {:ok, _tombstone} = Tasks.delete_task(task)

    {:noreply, stream_delete(socket, :tasks, task)}
  end

  defp load_assignees_for_tasks(tasks) do
    tasks
    |> Enum.map(fn task ->
      {task.entity_id, Tasks.list_assignees_for_task(task.entity_id)}
    end)
    |> Map.new()
  end

  defp format_assignees([]), do: "-"
  defp format_assignees(assignees) do
    assignees
    |> Enum.map(& &1.name)
    |> Enum.join(", ")
  end

  defp status_class("completed"), do: "text-green-600 font-medium"
  defp status_class("in_progress"), do: "text-blue-600 font-medium"
  defp status_class("cancelled"), do: "text-gray-400 line-through"
  defp status_class(_), do: "text-yellow-600"
end
