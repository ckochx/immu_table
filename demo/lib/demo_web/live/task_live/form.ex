defmodule DemoWeb.TaskLive.Form do
  use DemoWeb, :live_view

  alias Demo.Tasks
  alias Demo.Tasks.Task

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>
          <%= if @live_action == :edit do %>
            Editing will create version {@task.version + 1}. Previous versions remain unchanged.
          <% else %>
            Create a new task (version 1).
          <% end %>
        </:subtitle>
      </.header>

      <.form for={@form} id="task-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:title]} type="text" label="Title" required />
        <.input field={@form[:description]} type="textarea" label="Description" />
        <.input
          field={@form[:status]}
          type="select"
          label="Status"
          options={[
            {"Pending", "pending"},
            {"In Progress", "in_progress"},
            {"Completed", "completed"},
            {"Cancelled", "cancelled"}
          ]}
        />
        <.input
          field={@form[:priority]}
          type="select"
          label="Priority"
          options={[
            {"0 - None", 0},
            {"1 - Low", 1},
            {"2 - Medium", 2},
            {"3 - High", 3},
            {"4 - Critical", 4},
            {"5 - Urgent", 5}
          ]}
        />
        <.input field={@form[:due_date]} type="date" label="Due date" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">
            <%= if @live_action == :edit, do: "Update Task", else: "Create Task" %>
          </.button>
          <.button navigate={return_path(@return_to, @task)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"entity_id" => entity_id}) do
    task = Tasks.get_task!(entity_id)

    socket
    |> assign(:page_title, "Edit Task")
    |> assign(:task, task)
    |> assign(:form, to_form(Tasks.change_task(task)))
  end

  defp apply_action(socket, :new, _params) do
    task = %Task{status: "pending", priority: 0}

    socket
    |> assign(:page_title, "New Task")
    |> assign(:task, task)
    |> assign(:form, to_form(Tasks.change_task(task)))
  end

  @impl true
  def handle_event("validate", %{"task" => task_params}, socket) do
    changeset = Tasks.change_task(socket.assigns.task, task_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"task" => task_params}, socket) do
    save_task(socket, socket.assigns.live_action, task_params)
  end

  defp save_task(socket, :edit, task_params) do
    case Tasks.update_task(socket.assigns.task, task_params) do
      {:ok, task} ->
        {:noreply,
         socket
         |> put_flash(:info, "Task updated successfully (now version #{task.version})")
         |> push_navigate(to: return_path(socket.assigns.return_to, task))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_task(socket, :new, task_params) do
    case Tasks.create_task(task_params) do
      {:ok, task} ->
        {:noreply,
         socket
         |> put_flash(:info, "Task created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, task))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _task), do: ~p"/tasks"
  defp return_path("show", task), do: ~p"/tasks/#{task.entity_id}"
end
