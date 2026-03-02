defmodule LiveviewLabWeb.NotesLive do
  @moduledoc """
  Renders lesson notes from the notes/ directory as formatted HTML
  with syntax-highlighted code blocks.
  """
  use LiveviewLabWeb, :live_view

  # Resolve at compile time relative to project root
  @notes_dir Path.expand("notes", File.cwd!())

  @lessons %{
    "architecture" => "01-liveview-architecture.md",
    "lifecycle" => "02-lifecycle-callbacks.md",
    "assigns-reactivity" => "03-assigns-and-reactivity.md",
    "events" => "04-events-and-bindings.md",
    "navigation" => "05-navigation-and-routing.md",
    "function-components" => "06-function-components.md",
    "error-handling" => "07-error-handling-flash-uploads.md",
    "streams" => "08-streams-and-async.md",
    "streaming" => "09-real-time-streaming.md",
    "temporary-assigns" => "10-temporary-assigns-and-pagination.md",
    "components" => "11-livecomponents-deep-dive.md",
    "pubsub" => "12-pubsub-and-presence.md",
    "js-hooks" => "13-js-hooks-and-commands.md"
  }

  def mount(%{"lesson" => lesson_slug}, _session, socket) do
    case Map.get(@lessons, lesson_slug) do
      nil ->
        {:ok, push_navigate(socket, to: "/")}

      filename ->
        path = Path.join(@notes_dir, filename)

        html_content =
          case File.read(path) do
            {:ok, md} -> md_to_html(md)
            {:error, _} -> "<p>Could not read #{filename}.</p>"
          end

        socket =
          socket
          |> assign(
            page_title: "Notes: #{lesson_slug}",
            lesson_slug: lesson_slug,
            html_content: html_content,
            back_path: "/lessons/#{lesson_slug}"
          )

        {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-4">
        <.link navigate={@back_path} class="btn btn-ghost btn-sm">← Back to Lesson</.link>
        <.link navigate="/" class="btn btn-ghost btn-sm">Home</.link>
      </div>

      <article class="notes-content">
        {raw(@html_content)}
      </article>
    </div>
    """
  end

  defp md_to_html(markdown) do
    {:ok, html, _} = Earmark.as_html(markdown, code_class_prefix: "language-")

    html
    |> highlight_code_blocks()
  end

  defp highlight_code_blocks(html) do
    # Earmark outputs: <pre><code class="elixir language-elixir">...</code></pre>
    Regex.replace(
      ~r/<pre><code class="(\w+)[^"]*">([\s\S]*?)<\/code><\/pre>/,
      html,
      fn _full, lang, code ->
        highlighted = highlight(lang, unescape_html(code))
        ~s(<pre class="highlight bg-base-300 p-4 rounded-lg overflow-x-auto text-sm"><code>#{highlighted}</code></pre>)
      end
    )
  end

  defp highlight(lang, code) when lang in ~w(elixir heex) do
    Makeup.highlight(code, lexer: Makeup.Lexers.ElixirLexer) |> strip_makeup_wrapper()
  end

  defp highlight(lang, code) when lang in ~w(javascript js) do
    Makeup.highlight(code, lexer: Makeup.Lexers.JsLexer) |> strip_makeup_wrapper()
  end

  defp highlight("html", code) do
    Makeup.highlight(code, lexer: Makeup.Lexers.HTMLLexer) |> strip_makeup_wrapper()
  end

  defp highlight(_lang, code), do: code

  defp strip_makeup_wrapper(html) do
    html
    |> String.replace(~r/^<pre class="highlight"><code>/, "")
    |> String.replace(~r/<\/code><\/pre>$/, "")
  end

  defp unescape_html(html) do
    html
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
  end
end
