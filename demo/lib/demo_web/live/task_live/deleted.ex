defmodule DemoWeb.TaskLive.Deleted do
  use DemoWeb, :live_view

  alias Demo.Tasks

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Deleted Tasks
        <:subtitle>
          Tombstoned records. These can be restored at any time.
        </:subtitle>
        <:actions>
          <.button navigate={~p"/tasks"}>
            <.icon name="hero-arrow-left" /> Back to Active
          </.button>
        </:actions>
      </.header>

      <%= unless @has_deleted_tasks do %>
        <div class="mt-8 text-center py-12 bg-base-200 rounded-lg">
          <.icon name="hero-trash" class="mx-auto h-12 w-12 text-base-content/40" />
          <h3 class="mt-2 text-sm font-semibold">No deleted tasks</h3>
          <p class="mt-1 text-sm text-base-content/60">
            Deleted tasks will appear here. They can be restored from their history page.
          </p>
        </div>
      <% else %>
        <.table
          id="deleted-tasks"
          rows={@streams.tasks}
          row_click={fn {_id, task} -> JS.navigate(~p"/tasks/#{task.entity_id}/history") end}
        >
          <:col :let={{_id, task}} label="Title">
            <span class="line-through text-base-content/60">{task.title}</span>
          </:col>
          <:col :let={{_id, task}} label="Status">{task.status}</:col>
          <:col :let={{_id, task}} label="Deleted At">
            {format_datetime(task.deleted_at)}
          </:col>
          <:col :let={{_id, task}} label="Version">v{task.version}</:col>
          <:action :let={{_id, task}}>
            <.link navigate={~p"/tasks/#{task.entity_id}/history"}>
              History
            </.link>
          </:action>
          <:action :let={{_id, task}}>
            <.link
              phx-click={JS.push("restore", value: %{entity_id: task.entity_id})}
              data-confirm="Restore this task?"
            >
              Restore
            </.link>
          </:action>
        </.table>
      <% end %>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    deleted_tasks = Tasks.list_deleted_tasks()

    {:ok,
     socket
     |> assign(:page_title, "Deleted Tasks")
     |> assign(:has_deleted_tasks, length(deleted_tasks) > 0)
     |> stream(:tasks, deleted_tasks)}
  end

  @impl true
  def handle_event("restore", %{"entity_id" => entity_id}, socket) do
    case Tasks.fetch_task(entity_id) do
      {:error, :deleted} ->
        deleted_task =
          Tasks.get_task_history(entity_id)
          |> List.last()

        case Tasks.undelete_task(deleted_task) do
          {:ok, task} ->
            {:noreply,
             socket
             |> put_flash(:info, "Task restored (now version #{task.version})")
             |> stream_delete(:tasks, deleted_task)
             |> push_navigate(to: ~p"/tasks/#{task.entity_id}")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to restore: #{inspect(reason)}")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Task is not deleted")}
    end
  end

  defp format_datetime(nil), do: "—"
  defp format_datetime(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
end
