defmodule DemoWeb.NoteLive.Show do
  use DemoWeb, :live_view

  alias Demo.Notes

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@note.title}
        <:subtitle>Version {@note.version} &bull; Last updated {format_datetime(@note.valid_from)}</:subtitle>
        <:actions>
          <.button navigate={~p"/notes"}>
            <.icon name="hero-arrow-left" /> Back
          </.button>
          <.button navigate={~p"/notes/#{@note.entity_id}/history"}>
            <.icon name="hero-clock" /> History
          </.button>
          <.button variant="primary" navigate={~p"/notes/#{@note.entity_id}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Title">{@note.title}</:item>
        <:item title="Category">
          <span class="inline-flex items-center rounded-md bg-blue-100 px-2 py-1 text-xs text-blue-700">
            {@note.category}
          </span>
        </:item>
        <:item title="Content">
          <div class="whitespace-pre-wrap">{@note.content || "—"}</div>
        </:item>
      </.list>

      <div class="mt-8 p-4 bg-gray-50 rounded-lg">
        <h3 class="text-sm font-medium text-gray-500 mb-2">Immutable Metadata</h3>
        <dl class="grid grid-cols-3 gap-4 text-sm">
          <div>
            <dt class="text-gray-500">Entity ID</dt>
            <dd class="font-mono text-xs">{@note.entity_id}</dd>
          </div>
          <div>
            <dt class="text-gray-500">Version</dt>
            <dd>{@note.version}</dd>
          </div>
          <div>
            <dt class="text-gray-500">Valid From</dt>
            <dd>{format_datetime(@note.valid_from)}</dd>
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
     |> assign(:page_title, "Show Note")
     |> assign(:note, Notes.get_note!(entity_id))}
  end

  defp format_datetime(nil), do: "—"
  defp format_datetime(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
end
