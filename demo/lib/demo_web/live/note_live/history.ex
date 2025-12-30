defmodule DemoWeb.NoteLive.History do
  use DemoWeb, :live_view

  alias Demo.Notes

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Version History
        <:subtitle>
          Complete audit trail for this note. All versions are preserved forever.
        </:subtitle>
        <:actions>
          <.button navigate={~p"/notes"}>
            <.icon name="hero-arrow-left" /> Back to List
          </.button>
          <%= if @current_note do %>
            <.button navigate={~p"/notes/#{@entity_id}"}>
              View Current
            </.button>
          <% end %>
        </:actions>
      </.header>

      <div class="mt-8">
        <div class="flow-root">
          <ul role="list" class="-mb-8">
            <%= for {version, idx} <- Enum.with_index(@versions) do %>
              <li>
                <div class="relative pb-8">
                  <%= if idx < length(@versions) - 1 do %>
                    <span class="absolute left-4 top-4 -ml-px h-full w-0.5 bg-gray-200" aria-hidden="true"></span>
                  <% end %>
                  <div class="relative flex space-x-3">
                    <div>
                      <span class={[
                        "h-8 w-8 rounded-full flex items-center justify-center ring-8 ring-white",
                        version_badge_class(version)
                      ]}>
                        <span class="text-white text-sm font-medium">v{version.version}</span>
                      </span>
                    </div>
                    <div class="flex min-w-0 flex-1 justify-between space-x-4 pt-1.5">
                      <div>
                        <p class="text-sm text-gray-500">
                          <%= version_action(version) %>
                          <span class="font-medium text-gray-900">{version.title}</span>
                        </p>
                        <%= if version.content do %>
                          <p class="mt-1 text-sm text-gray-500 line-clamp-2">{version.content}</p>
                        <% end %>
                        <div class="mt-2 flex flex-wrap gap-2 text-xs">
                          <span class="inline-flex items-center rounded-md bg-blue-100 px-2 py-1 text-blue-700">
                            {version.category}
                          </span>
                        </div>
                      </div>
                      <div class="whitespace-nowrap text-right text-sm text-gray-500">
                        <time datetime={version.valid_from}>
                          {format_datetime(version.valid_from)}
                        </time>
                        <p class="text-xs text-gray-400 font-mono mt-1">
                          {String.slice(version.id, 0, 8)}...
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
              </li>
            <% end %>
          </ul>
        </div>
      </div>

      <%= if @deleted_note do %>
        <div class="mt-8 p-4 bg-red-50 rounded-lg border border-red-200">
          <div class="flex">
            <div class="flex-shrink-0">
              <.icon name="hero-trash" class="h-5 w-5 text-red-400" />
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-red-800">This note is deleted</h3>
              <div class="mt-2 text-sm text-red-700">
                <p>The note was deleted but all history is preserved. You can restore it if needed.</p>
              </div>
              <div class="mt-4">
                <.button
                  phx-click="undelete"
                  data-confirm="Restore this note?"
                  variant="primary"
                >
                  <.icon name="hero-arrow-path" /> Restore Note
                </.button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"entity_id" => entity_id}, _session, socket) do
    versions = Notes.get_note_history(entity_id)
    current_note = Notes.get_note(entity_id)
    deleted_note = if is_nil(current_note), do: List.last(versions), else: nil

    {:ok,
     socket
     |> assign(:page_title, "Note History")
     |> assign(:entity_id, entity_id)
     |> assign(:versions, Enum.reverse(versions))
     |> assign(:current_note, current_note)
     |> assign(:deleted_note, deleted_note)}
  end

  @impl true
  def handle_event("undelete", _params, socket) do
    case Notes.undelete_note(socket.assigns.deleted_note) do
      {:ok, note} ->
        {:noreply,
         socket
         |> put_flash(:info, "Note restored successfully (now version #{note.version})")
         |> push_navigate(to: ~p"/notes/#{note.entity_id}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to restore: #{inspect(reason)}")}
    end
  end

  defp version_action(%{version: 1}), do: "Created"
  defp version_action(%{deleted_at: nil}), do: "Updated"
  defp version_action(%{deleted_at: _}), do: "Deleted"

  defp version_badge_class(%{version: 1}), do: "bg-green-500"
  defp version_badge_class(%{deleted_at: nil}), do: "bg-blue-500"
  defp version_badge_class(%{deleted_at: _}), do: "bg-red-500"

  defp format_datetime(nil), do: "—"
  defp format_datetime(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
end
