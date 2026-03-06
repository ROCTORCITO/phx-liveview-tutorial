# Lesson 7: Error Handling, Flash & Uploads

## Overview

Production LiveView applications need to handle errors gracefully, communicate
feedback to users, and support file uploads. This lesson covers three interconnected
topics: flash messages for user feedback, error handling patterns in LiveView
callbacks, and the file upload lifecycle.

Flash messages are the primary way to show success/error feedback. Error handling
ensures your LiveView recovers gracefully from failures. File uploads add a complete
client-to-server file transfer pipeline built into LiveView's WebSocket connection
— no JavaScript file upload libraries needed.

**Source file:** `lib/liveview_lab_web/live/lesson7_error_handling_live.ex`

---

## Core Concepts

### 1. Flash Messages

Flash messages are short-lived notifications displayed to the user. LiveView provides
two standard flash types: `:info` (success/neutral) and `:error`.

```elixir
# Setting flash messages in any callback
def handle_event("save", params, socket) do
  case save_record(params) do
    {:ok, _record} ->
      {:noreply,
       socket
       |> put_flash(:info, "Record saved successfully!")
       |> push_navigate(to: ~p"/records")}

    {:error, _changeset} ->
      {:noreply, put_flash(socket, :error, "Failed to save. Please check the form.")}
  end
end

# Flash in handle_info
def handle_info({:task_complete, result}, socket) do
  {:noreply, put_flash(socket, :info, "Background task finished: #{result}")}
end
```

**Rendering flash messages in the template:**

```heex
<%!-- CoreComponents provides <.flash_group> which renders both :info and :error --%>
<.flash_group flash={@flash} />

<%!-- Or render manually --%>
<p :if={msg = Phoenix.Flash.get(@flash, :info)} class="flash-info">
  {msg}
</p>
<p :if={msg = Phoenix.Flash.get(@flash, :error)} class="flash-error">
  {msg}
</p>
```

**Flash behavior:**
- Flash messages are **automatically cleared on the next navigation** (patch or
  navigate). This is built into LiveView's navigation lifecycle.
- Flash is stored per-socket, not per-session. Each LiveView process has its own
  flash.
- You can clear flash manually with `clear_flash(socket)` or
  `clear_flash(socket, :info)`.

---

### 2. Error Handling in handle_event

Every `handle_event/3` should account for failures. Unhandled errors crash the
LiveView process.

#### Pattern Matching for Expected Failures

```elixir
# Handle expected error cases with pattern matching
def handle_event("delete", %{"id" => id}, socket) do
  case Items.delete_item(id) do
    {:ok, _item} ->
      {:noreply,
       socket
       |> put_flash(:info, "Item deleted")
       |> assign(items: Items.list_items())}

    {:error, :not_found} ->
      {:noreply, put_flash(socket, :error, "Item not found — it may have been deleted already")}

    {:error, :has_dependencies} ->
      {:noreply, put_flash(socket, :error, "Cannot delete: item is referenced by other records")}
  end
end
```

#### try/rescue for External Calls

```elixir
# Wrap calls to external services that may raise
def handle_event("fetch_weather", %{"city" => city}, socket) do
  try do
    weather = WeatherAPI.get_current(city)
    {:noreply, assign(socket, weather: weather)}
  rescue
    e in HTTPoison.Error ->
      {:noreply, put_flash(socket, :error, "Weather service unavailable: #{Exception.message(e)}")}

    e in Jason.DecodeError ->
      {:noreply, put_flash(socket, :error, "Received invalid data from weather service")}
  end
end
```

#### Changeset Error Patterns

```elixir
def handle_event("save", %{"user" => user_params}, socket) do
  case Accounts.create_user(user_params) do
    {:ok, user} ->
      {:noreply,
       socket
       |> put_flash(:info, "User #{user.name} created!")
       |> push_navigate(to: ~p"/users/#{user}")}

    {:error, %Ecto.Changeset{} = changeset} ->
      # Re-render the form with validation errors
      {:noreply, assign(socket, form: to_form(changeset))}
  end
end
```

#### Form Validation with Inline Errors (Without Ecto)

The source demonstrates a pattern for form validation using a separate `@validation_errors`
map assign — useful when you don't want Ecto changesets:

```elixir
# In mount: initialize with empty errors
assign(socket,
  validation_form: to_form(%{"email" => "", "age" => ""}, as: "user"),
  validation_errors: %{}
)

# On submit: validate params, store errors in a map assign
def handle_event("validate_form", %{"user" => params}, socket) do
  errors = validate_user_params(params)

  socket =
    socket
    |> assign(validation_form: to_form(params, as: "user"), validation_errors: errors)

  if map_size(errors) == 0 do
    {:noreply, put_flash(socket, :info, "Form is valid!")}
  else
    {:noreply, put_flash(socket, :error, "Validation failed: #{map_size(errors)} error(s)")}
  end
end

defp validate_user_params(params) do
  errors = %{}

  errors =
    if String.match?(params["email"] || "", ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/) do
      errors
    else
      Map.put(errors, :email, "Must be a valid email address")
    end

  errors =
    case Integer.parse(params["age"] || "") do
      {num, ""} when num >= 18 and num <= 120 -> errors
      _ -> Map.put(errors, :age, "Must be a number between 18 and 120")
    end

  errors
end
```

**In the template** — use `@validation_errors` to conditionally apply error styles:

```heex
<input
  name="user[email]"
  value={@validation_form[:email].value}
  class={["input input-bordered", @validation_errors[:email] && "input-error"]}
/>
<p :if={@validation_errors[:email]} class="text-error text-xs mt-1">
  {@validation_errors[:email]}
</p>
```

This approach keeps error display separate from the form struct — errors are in a
plain map, not in `to_form`'s error keyword list. It's simpler for cases where you
don't need `<.input>` component's built-in error rendering.

**Key principle:** Never let `handle_event` crash silently. Every code path should
either update the socket with meaningful feedback or explicitly handle the error.

---

### 3. LiveView Crash Recovery

LiveView processes are Erlang processes. If one crashes, it doesn't take down the
application — only that one user's connection is affected.

```
LiveView process crashes
  → WebSocket disconnects
    → Client shows "reconnecting" indicator (automatic)
      → Client reconnects via WebSocket
        → mount/3 runs again (fresh state)
          → User sees a brief flash and the view reloads
```

**What this means in practice:**
- Crashes are **not catastrophic** — the user experiences a brief flicker and the
  view restarts. This is by design: the BEAM's "let it crash" philosophy.
- **mount/3 must be resilient** — since it runs again on reconnect, it should be
  able to rebuild state from the database/session, not rely on in-memory state that
  was lost.
- The reconnecting indicator is built into LiveView's JavaScript client. You can
  customize it with CSS:

```css
/* Shown automatically when the WebSocket is reconnecting */
[phx-disconnected] {
  opacity: 0.5;
  pointer-events: none;
}

/* The reconnect message */
#phx-disconnected {
  display: none;
}
[phx-disconnected] #phx-disconnected {
  display: block;
}
```

---

### 4. File Uploads Overview

LiveView has built-in file upload support over the WebSocket. No JavaScript file
upload libraries, no separate HTTP endpoints, no presigned URLs needed (though
external uploads are also supported).

The upload lifecycle:

```
allow_upload/3 in mount
  → User selects file (via <.live_file_input>)
    → Entries appear in @uploads.name.entries
      → Client streams file chunks over WebSocket
        → Validate entries
          → consume_uploaded_entries/3 to process files
            → Temp files cleaned up automatically
```

---

### 5. Upload Configuration

Configure uploads in `mount/3` with `allow_upload/3`.

```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(form: to_form(%{}))
   |> allow_upload(:avatar,
     accept: ~w(.jpg .jpeg .png .webp),   # Allowed file extensions
     max_entries: 1,                        # Max number of files
     max_file_size: 5_000_000,             # 5 MB (in bytes)
     auto_upload: false                     # If true, upload starts immediately on select
   )
   |> allow_upload(:documents,
     accept: ~w(.pdf .doc .docx),
     max_entries: 5,
     max_file_size: 10_000_000
   )}
end
```

**Configuration options:**

| Option | Description | Default |
|---|---|---|
| `accept` | MIME types or extensions | Required |
| `max_entries` | Max files allowed | Required |
| `max_file_size` | Max size per file (bytes) | 8 MB |
| `auto_upload` | Upload on file select (no submit needed) | `false` |
| `progress` | Progress callback function | None |
| `chunk_size` | WebSocket chunk size (bytes) | 64 KB |

---

### 6. Upload Template

```heex
<.form for={@form} phx-change="validate" phx-submit="save">
  <%!-- File input bound to the :avatar upload config --%>
  <.live_file_input upload={@uploads.avatar} />

  <%!-- Live image preview for selected (not yet uploaded) files --%>
  <div :for={entry <- @uploads.avatar.entries} class="upload-entry">
    <.live_img_preview entry={entry} width="100" />

    <p>{entry.client_name} ({entry.client_size} bytes)</p>

    <%!-- Upload progress bar --%>
    <progress value={entry.progress} max="100">
      {entry.progress}%
    </progress>

    <%!-- Per-entry errors --%>
    <p :for={err <- upload_errors(@uploads.avatar, entry)} class="error">
      {upload_error_to_string(err)}
    </p>

    <%!-- Cancel button --%>
    <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref}>
      Cancel
    </button>
  </div>

  <%!-- Config-level errors (e.g., too many files) --%>
  <p :for={err <- upload_errors(@uploads.avatar)} class="error">
    {upload_error_to_string(err)}
  </p>

  <button type="submit">Upload</button>
</.form>
```

```elixir
# Cancel an upload entry
def handle_event("cancel-upload", %{"ref" => ref}, socket) do
  {:noreply, cancel_upload(socket, :avatar, ref)}
end
```

**`live_img_preview/2`** works for image files only. It reads the file locally in
the browser (no server round-trip) to show a preview before upload.

---

### 7. Upload Errors

Upload errors come from two sources: configuration violations and per-entry issues.

```elixir
# Config-level errors (e.g., too many files selected)
upload_errors(@uploads.avatar)
# Returns: [:too_many_files] or []

# Per-entry errors (e.g., file too large, wrong type)
upload_errors(@uploads.avatar, entry)
# Returns: [:too_large, :not_accepted] or []

# Human-readable error messages
defp upload_error_to_string(:too_large), do: "File is too large"
defp upload_error_to_string(:too_many_files), do: "Too many files selected"
defp upload_error_to_string(:not_accepted), do: "File type not accepted"
defp upload_error_to_string(:external_client_failure), do: "Upload failed"
```

**Possible error atoms:**

| Error | Level | Cause |
|---|---|---|
| `:too_many_files` | Config | More files than `max_entries` |
| `:too_large` | Entry | File exceeds `max_file_size` |
| `:not_accepted` | Entry | File type not in `accept` list |
| `:external_client_failure` | Entry | External upload failed |

---

### 8. Consuming Uploads

After the form is submitted, use `consume_uploaded_entries/3` to process the files.
This is the only way to access the uploaded file data.

```elixir
def handle_event("save", _params, socket) do
  uploaded_files =
    consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
      # path = absolute path to the temp file on disk
      # entry = %Phoenix.LiveView.UploadEntry{} with metadata

      # Example: copy to a permanent location
      dest = Path.join(["priv", "static", "uploads", entry.client_name])
      File.cp!(path, dest)

      {:ok, ~p"/uploads/#{entry.client_name}"}
    end)

  {:noreply,
   socket
   |> put_flash(:info, "Uploaded #{length(uploaded_files)} file(s)")
   |> assign(uploaded_files: uploaded_files)}
end
```

**The callback receives two arguments:**

1. `meta` — a map with `:path` (the temp file path on disk). For external uploads
   this contains different keys.
2. `entry` — a `%Phoenix.LiveView.UploadEntry{}` struct with:
   - `entry.client_name` — original filename
   - `entry.client_size` — file size in bytes
   - `entry.client_type` — MIME type (e.g., `"image/png"`)
   - `entry.ref` — unique reference for this upload entry
   - `entry.progress` — upload progress (0-100)

**Important:** The temp file at `meta.path` is automatically deleted after
`consume_uploaded_entries/3` returns. You must copy or process it within the
callback.

```elixir
# Example: upload to S3 (using an imaginary S3 module)
consume_uploaded_entries(socket, :documents, fn %{path: path}, entry ->
  {:ok, url} = S3.upload(path, key: "docs/#{entry.client_name}")
  {:ok, url}
end)
```

---

### 9. Upload Progress

Track upload progress with `entry.progress` (integer from 0 to 100).

```heex
<div :for={entry <- @uploads.avatar.entries}>
  <p>{entry.client_name}</p>

  <%!-- Progress bar --%>
  <div class="progress-bar">
    <div class="progress-fill" style={"width: #{entry.progress}%"}></div>
  </div>
  <span>{entry.progress}%</span>
</div>
```

**Drag and drop:** Use `phx-drop-target` to designate a drop zone.

```heex
<div
  phx-drop-target={@uploads.avatar.ref}
  class="drop-zone"
>
  <p>Drag files here or</p>
  <.live_file_input upload={@uploads.avatar} />
</div>

<style>
  .drop-zone {
    border: 2px dashed #ccc;
    padding: 2rem;
    text-align: center;
  }
  /* LiveView adds this class when a file is dragged over the target */
  .drop-zone.phx-drop-target {
    border-color: #4299e1;
    background: #ebf8ff;
  }
</style>
```

The `phx-drop-target` attribute takes the upload ref (`@uploads.avatar.ref`) and
makes the element a valid drop target for that upload config.

---

### 10. Putting It All Together

A complete upload form with validation, preview, progress, and error handling:

```elixir
defmodule MyAppWeb.UploadLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(uploaded_files: [])
     |> allow_upload(:photos,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 3,
       max_file_size: 5_000_000
     )}
  end

  def handle_event("validate", _params, socket) do
    # Validation happens automatically based on allow_upload config.
    # Errors appear in upload_errors/1 and upload_errors/2.
    {:noreply, socket}
  end

  def handle_event("save", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :photos, fn %{path: path}, entry ->
        dest = Path.join(["priv", "static", "uploads", entry.client_name])
        File.cp!(path, dest)
        {:ok, ~p"/uploads/#{entry.client_name}"}
      end)

    {:noreply,
     socket
     |> put_flash(:info, "#{length(uploaded_files)} photo(s) uploaded!")
     |> update(:uploaded_files, &(&1 ++ uploaded_files))}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photos, ref)}
  end

  def render(assigns) do
    ~H"""
    <h2>Upload Photos</h2>

    <.form for={%{}} phx-change="validate" phx-submit="save">
      <div phx-drop-target={@uploads.photos.ref} class="drop-zone">
        <.live_file_input upload={@uploads.photos} />
        <p>or drag and drop (max 3 files, 5MB each)</p>
      </div>

      <%!-- Config errors --%>
      <p :for={err <- upload_errors(@uploads.photos)} class="error">
        {upload_error_to_string(err)}
      </p>

      <%!-- Entries with preview, progress, errors --%>
      <div :for={entry <- @uploads.photos.entries} class="upload-entry">
        <.live_img_preview entry={entry} width="150" />
        <p>{entry.client_name} — {entry.progress}%</p>
        <progress value={entry.progress} max="100" />

        <p :for={err <- upload_errors(@uploads.photos, entry)} class="error">
          {upload_error_to_string(err)}
        </p>

        <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref}>
          Remove
        </button>
      </div>

      <button type="submit">Upload</button>
    </.form>

    <%!-- Show uploaded files --%>
    <div :for={url <- @uploaded_files}>
      <img src={url} width="200" />
    </div>
    """
  end

  defp upload_error_to_string(:too_large), do: "File is too large (max 5MB)"
  defp upload_error_to_string(:too_many_files), do: "Too many files (max 3)"
  defp upload_error_to_string(:not_accepted), do: "Only .jpg, .jpeg, .png accepted"
end
```

---

## Common Pitfalls

1. **Forgetting to consume uploads** — If you don't call
   `consume_uploaded_entries/3` in your submit handler, the temp files are cleaned
   up automatically when the LiveView process terminates, and you lose the uploads.
   Always consume in the submit handler.

2. **Not handling upload errors** — Users can select files that are too large or the
   wrong type. Always render `upload_errors/1` (config-level) and
   `upload_errors/2` (per-entry) in your template.

3. **Flash messages disappearing too fast** — Flash is auto-cleared on navigation.
   If you `put_flash` and then immediately `push_navigate`, the user sees the flash
   on the new page but it disappears on the next navigation. For persistent
   messages, use assigns instead of flash.

4. **Not wrapping external calls in try/rescue** — HTTP calls, file I/O, and other
   external operations can raise. An unhandled exception in `handle_event` crashes
   the LiveView process. Wrap risky calls and show user-friendly error messages.

5. **Relying on in-memory state after crash** — When a LiveView crashes and
   reconnects, `mount/3` runs from scratch. Any state that was only in assigns is
   lost. Important state should be persisted (database, session, URL params) so
   `mount` can rebuild it.

6. **Processing uploads outside consume_uploaded_entries** — The temp file path is
   only valid inside the `consume_uploaded_entries` callback. If you try to access
   it later, the file will have been deleted.

---

## Exercises

1. Build a form with `put_flash` feedback: show `:info` on success and `:error`
   on validation failure
2. Implement error handling for a `handle_event` that calls an external API — use
   `try/rescue` and display the error via flash
3. Create a single-file image upload with live preview (`live_img_preview`),
   progress bar, and error display
4. Build a multi-file upload (max 5 files) with drag-and-drop using
   `phx-drop-target`, per-entry cancel buttons, and per-entry error messages
5. Add a crash recovery exercise: intentionally crash a LiveView (raise in
   `handle_event`), observe the reconnect behavior, and ensure `mount` rebuilds
   state from the database
