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
        <:col :let={{_id, task}} label="Due date">{task.due_date}</:col>
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
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Tasks")
     |> stream(:tasks, Tasks.list_tasks(), dom_id: &"tasks-#{&1.entity_id}")}
  end

  @impl true
  def handle_event("delete", %{"entity_id" => entity_id}, socket) do
    task = Tasks.get_task!(entity_id)
    {:ok, _tombstone} = Tasks.delete_task(task)

    {:noreply, stream_delete(socket, :tasks, task)}
  end

  defp status_class("completed"), do: "text-green-600 font-medium"
  defp status_class("in_progress"), do: "text-blue-600 font-medium"
  defp status_class("cancelled"), do: "text-gray-400 line-through"
  defp status_class(_), do: "text-yellow-600"
end
