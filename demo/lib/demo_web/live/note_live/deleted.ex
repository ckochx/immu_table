defmodule DemoWeb.NoteLive.Deleted do
  use DemoWeb, :live_view

  alias Demo.Notes

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Deleted Notes
        <:subtitle>
          Tombstoned records. These can be restored at any time.
        </:subtitle>
        <:actions>
          <.button navigate={~p"/notes"}>
            <.icon name="hero-arrow-left" /> Back to Active
          </.button>
        </:actions>
      </.header>

      <%= unless @has_deleted_notes do %>
        <div class="mt-8 text-center py-12 bg-base-200 rounded-lg">
          <.icon name="hero-trash" class="mx-auto h-12 w-12 text-base-content/40" />
          <h3 class="mt-2 text-sm font-semibold">No deleted notes</h3>
          <p class="mt-1 text-sm text-base-content/60">
            Deleted notes will appear here. They can be restored from their history page.
          </p>
        </div>
      <% else %>
        <.table
          id="deleted-notes"
          rows={@streams.notes}
          row_click={fn {_id, note} -> JS.navigate(~p"/notes/#{note.entity_id}/history") end}
        >
          <:col :let={{_id, note}} label="Title">
            <span class="line-through text-base-content/60">{note.title}</span>
          </:col>
          <:col :let={{_id, note}} label="Category">{note.category}</:col>
          <:col :let={{_id, note}} label="Deleted At">
            {format_datetime(note.deleted_at)}
          </:col>
          <:col :let={{_id, note}} label="Version">v{note.version}</:col>
          <:action :let={{_id, note}}>
            <.link navigate={~p"/notes/#{note.entity_id}/history"}>
              History
            </.link>
          </:action>
          <:action :let={{_id, note}}>
            <.link
              phx-click={JS.push("restore", value: %{entity_id: note.entity_id})}
              data-confirm="Restore this note?"
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
    deleted_notes = Notes.list_deleted_notes()

    {:ok,
     socket
     |> assign(:page_title, "Deleted Notes")
     |> assign(:has_deleted_notes, length(deleted_notes) > 0)
     |> stream(:notes, deleted_notes, dom_id: &"notes-#{&1.entity_id}")}
  end

  @impl true
  def handle_event("restore", %{"entity_id" => entity_id}, socket) do
    case Notes.fetch_note(entity_id) do
      {:error, :deleted} ->
        deleted_note =
          Notes.get_note_history(entity_id)
          |> List.last()

        case Notes.undelete_note(deleted_note) do
          {:ok, note} ->
            {:noreply,
             socket
             |> put_flash(:info, "Note restored (now version #{note.version})")
             |> stream_delete(:notes, deleted_note)
             |> push_navigate(to: ~p"/notes/#{note.entity_id}")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to restore: #{inspect(reason)}")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Note is not deleted")}
    end
  end

  defp format_datetime(nil), do: "—"
  defp format_datetime(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
end
