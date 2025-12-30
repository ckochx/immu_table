defmodule DemoWeb.TaskLive.Show do
  use DemoWeb, :live_view

  alias Demo.Tasks

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@task.title}
        <:subtitle>Version {@task.version} &bull; Last updated {format_datetime(@task.valid_from)}</:subtitle>
        <:actions>
          <.button navigate={~p"/tasks"}>
            <.icon name="hero-arrow-left" /> Back
          </.button>
          <.button navigate={~p"/tasks/#{@task.entity_id}/history"}>
            <.icon name="hero-clock" /> History
          </.button>
          <.button variant="primary" navigate={~p"/tasks/#{@task.entity_id}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Title">{@task.title}</:item>
        <:item title="Description">{@task.description || "—"}</:item>
        <:item title="Status">{@task.status}</:item>
        <:item title="Priority">{@task.priority}</:item>
        <:item title="Due date">{@task.due_date || "—"}</:item>
      </.list>

      <div class="mt-8 p-4 bg-gray-50 rounded-lg">
        <h3 class="text-sm font-medium text-gray-500 mb-2">Immutable Metadata</h3>
        <dl class="grid grid-cols-3 gap-4 text-sm">
          <div>
            <dt class="text-gray-500">Entity ID</dt>
            <dd class="font-mono text-xs">{@task.entity_id}</dd>
          </div>
          <div>
            <dt class="text-gray-500">Version</dt>
            <dd>{@task.version}</dd>
          </div>
          <div>
            <dt class="text-gray-500">Valid From</dt>
            <dd>{format_datetime(@task.valid_from)}</dd>
          </div>
        </dl>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"entity_id" => entity_id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Task")
     |> assign(:task, Tasks.get_task!(entity_id))}
  end

  defp format_datetime(nil), do: "—"
  defp format_datetime(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
end
