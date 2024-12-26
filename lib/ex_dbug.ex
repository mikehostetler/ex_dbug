defmodule ExDbug do
  @external_resource "README.md"
  @moduledoc File.read!("README.md")
             |> String.split("## Contributing")
             |> List.first()
             |> String.trim()

  require Logger

  @type debug_opts :: [
          enabled: boolean(),
          context: atom() | String.t(),
          max_depth: non_neg_integer(),
          include_timing: boolean(),
          include_stack: boolean(),
          max_length: non_neg_integer(),
          truncate_threshold: non_neg_integer()
        ]

  defmacro __using__(opts \\ []) do
    enabled = get_debug_enabled(opts)

    if enabled do
      quote do
        import ExDbug
        require Logger
        require ExDbug

        @debug_opts ExDbug.merge_options(unquote(opts))
        @context Keyword.get(unquote(opts), :context, __MODULE__) |> to_string()

        @before_compile ExDbug
      end
    else
      quote do
        require Logger
        defmacro dbug(_, _ \\ [], _ \\ []), do: nil
        defmacro error(_, _ \\ [], _ \\ []), do: nil
        def __debug_context__, do: nil
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __debug_context__, do: @context
    end
  end

  defmacro dbug(message, metadata \\ [], opts \\ []) do
    quote bind_quoted: [message: message, metadata: metadata, opts: opts] do
      context = __debug_context__()
      ExDbug.log(:debug, message, metadata, Map.new(@debug_opts))
    end
  end

  defmacro error(message, metadata \\ [], opts \\ []) do
    quote bind_quoted: [message: message, metadata: metadata, opts: opts] do
      context = __debug_context__()
      ExDbug.log(:error, message, metadata, Map.new(@debug_opts))
    end
  end

  defmacro track(value, name) do
    quote do
      result = unquote(value)
      dbug("Value tracked: #{unquote(name)} = #{inspect(result)}")
      result
    end
  end

  @doc false
  def get_debug_enabled(opts) do
    env_enabled = Application.get_env(:ex_dbug, :enabled, true)
    Keyword.get(opts, :enabled, env_enabled)
  end

  @doc false
  def merge_options(opts) do
    defaults = [
      max_depth: 3,
      include_timing: true,
      include_stack: true,
      max_length: 500,
      truncate_threshold: 100,
      levels: [:debug, :error]
    ]

    app_config = Application.get_env(:ex_dbug, :config, [])
    Keyword.merge(defaults, app_config) |> Keyword.merge(opts)
  end

  @doc false
  def format_output(message, context) do
    format_output(message, context, [])
  end

  @doc false
  def format_output(message, context, metadata, opts \\ %{}) do
    formatted_metadata = format_metadata(metadata, opts)
    base = "[#{context}] #{message}"

    if formatted_metadata != "", do: "#{base} #{formatted_metadata}", else: base
  end

  @doc false
  def log(level, message, metadata, context)
      when level in [:debug, :error] and (is_binary(context) or is_atom(context)) do
    context_str = to_string(context)

    if should_log?(level, metadata, context_str) do
      formatted = format_output(message, context_str, metadata)

      case level do
        :debug -> Logger.debug(formatted)
        :error -> Logger.error(formatted)
      end
    end
  end

  @doc false
  def log(level, message, metadata, opts) when level in [:debug, :error] and is_map(opts) do
    context = Map.get(opts, :context) || "unknown"
    log(level, message, metadata, context)
  end

  @doc false
  defp should_log?(level, metadata, context) do
    debug_levels = Keyword.get(metadata, :levels, [:debug, :error])
    level_allowed = level in debug_levels
    pattern_match = namespace_enabled?(context)

    level_allowed and pattern_match
  end

  @doc false
  defp namespace_enabled?(context) do
    patterns = parse_debug_env()
    matches_namespace?(context, patterns)
  end

  @doc false
  defp parse_debug_env do
    debug_val = System.get_env("DEBUG", "")
    parse_patterns(debug_val)
  end

  @doc false
  defp parse_patterns(string) when is_binary(string) do
    raw = String.split(string, [",", " "], trim: true)

    {includes, excludes} =
      Enum.reduce(raw, {[], []}, fn pattern, {inc, exc} ->
        pattern = String.trim(pattern)

        cond do
          pattern == "" ->
            {inc, exc}

          String.starts_with?(pattern, "-") ->
            {inc, [String.trim_leading(pattern, "-") | exc]}

          true ->
            {[pattern | inc], exc}
        end
      end)

    {Enum.reverse(includes), Enum.reverse(excludes)}
  end

  @doc false
  defp matches_namespace?(namespace, {includes, excludes}) do
    cond do
      includes == [] and excludes == [] ->
        true

      true ->
        included = includes == [] or Enum.any?(includes, &wildcard_match?(namespace, &1))
        excluded = Enum.any?(excludes, &wildcard_match?(namespace, &1))
        included and not excluded
    end
  end

  @doc false
  defp wildcard_match?(string, pattern) do
    regex_pattern =
      pattern
      |> Regex.escape()
      |> String.replace("\\*", ".*")

    Regex.match?(Regex.compile!("^" <> regex_pattern <> "$"), string)
  end

  # Private helper functions for metadata formatting
  defp format_metadata(metadata, opts) when is_list(metadata) do
    max_length = Map.get(opts, :max_length, 500)
    truncate_threshold = Map.get(opts, :truncate_threshold, 100)

    case metadata do
      [] ->
        ""

      _ ->
        Enum.map_join(metadata, ", ", fn {key, value} ->
          formatted_value = format_value(value, max_length, truncate_threshold)
          "#{key}: #{formatted_value}"
        end)
    end
  end

  defp format_metadata(_, _), do: ""

  defp format_value(value, max_length, truncate_threshold) do
    formatted = inspect(value, limit: :infinity, pretty: false)

    if String.length(formatted) > truncate_threshold do
      truncated = String.slice(formatted, 0, max_length)
      "#{truncated}... (truncated)"
    else
      formatted
    end
  end
end
