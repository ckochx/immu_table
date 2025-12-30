defmodule DemoWeb.NoteLive.Index do
  use DemoWeb, :live_view

  alias Demo.Notes

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Notes
        <:subtitle>
          All changes create new versions. Nothing is ever truly deleted.
        </:subtitle>
        <:actions>
          <.button navigate={~p"/notes/deleted"}>
            <.icon name="hero-trash" /> Deleted
          </.button>
          <.button variant="primary" navigate={~p"/notes/new"}>
            <.icon name="hero-plus" /> New Note
          </.button>
        </:actions>
      </.header>

      <.table
        id="notes"
        rows={@streams.notes}
        row_click={fn {_id, note} -> JS.navigate(~p"/notes/#{note.entity_id}") end}
      >
        <:col :let={{_id, note}} label="Title">{note.title}</:col>
        <:col :let={{_id, note}} label="Category">
          <span class="inline-flex items-center rounded-md bg-blue-100 px-2 py-1 text-xs text-blue-700">
            {note.category}
          </span>
        </:col>
        <:col :let={{_id, note}} label="Version">v{note.version}</:col>
        <:action :let={{_id, note}}>
          <.link navigate={~p"/notes/#{note.entity_id}/history"}>History</.link>
        </:action>
        <:action :let={{_id, note}}>
          <.link navigate={~p"/notes/#{note.entity_id}/edit"}>Edit</.link>
        </:action>
        <:action :let={{_id, note}}>
          <.link
            phx-click={JS.push("delete", value: %{entity_id: note.entity_id}) |> hide("#notes-#{note.entity_id}")}
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
     |> assign(:page_title, "Notes")
     |> stream(:notes, Notes.list_notes(), dom_id: &"notes-#{&1.entity_id}")}
  end

  @impl true
  def handle_event("delete", %{"entity_id" => entity_id}, socket) do
    note = Notes.get_note!(entity_id)
    {:ok, _tombstone} = Notes.delete_note(note)

    {:noreply, stream_delete(socket, :notes, note)}
  end
end
