defmodule ExDbug do
  @moduledoc """
  Advanced debug utility for debugging and analysis, inspired by the Node.js 'debug' package.

  ## Usage

  Add `use ExDbug, context: :my_namespace` to a module, and use `dbug/1` or `error/1` to log debug or error messages.

  Debug output is controlled by:
    - The `:enabled` config key for `:ex_dbug` (compile-time)
    - The `DEBUG` environment variable (runtime), which determines which namespaces are displayed

  ### Enabling/Disabling at Compile Time

  In your `config.exs`:
  ```elixir
  config :ex_dbug, enabled: true
  ```
  If `enabled: false`, calls to `dbug` and `error` are compiled out (no runtime overhead).

  ### Using DEBUG Environment Variable

  Set `DEBUG` to enable certain namespaces:
    - `DEBUG="*"` enables all namespaces
    - `DEBUG="myapp:*"` enables all namespaces starting with myapp:
    - `DEBUG="*,-myapp:db"` enables all but myapp:db

  You can separate multiple patterns with commas. A leading `-` excludes a pattern.

  Example:
  ```bash
  DEBUG="myapp:*" mix run
  ```

  ### Example
  ```elixir
  defmodule MyModule do
    use ExDbug, context: :my_feature

    def run do
      dbug("Starting run")
      :ok
    end
  end
  ```
  If `DEBUG="my_feature"`, calling `MyModule.run()` will log the debug message.

  ## Features
    - Namespace-based enabling/disabling of debug output
    - Compile-time toggle to remove debug calls entirely
    - Stack trace or timing info can be integrated if desired
    - Works similar to the Node.js 'debug' library
  """

  require Logger

  @type debug_opts :: [
          enabled: boolean(),
          context: atom() | String.t(),
          max_depth: non_neg_integer(),
          include_timing: boolean(),
          include_stack: boolean()
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
      # If not enabled, we compile out the macros to no-ops
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
    # dbug calls are only compiled if enabled is true
    quote bind_quoted: [message: message, metadata: metadata, opts: opts] do
      context = __debug_context__()
      ExDbug.log(:debug, message, @debug_opts, context)
    end
  end

  defmacro error(message, metadata \\ [], opts \\ []) do
    quote bind_quoted: [message: message, metadata: metadata, opts: opts] do
      context = __debug_context__()
      ExDbug.log(:error, message, @debug_opts, context)
    end
  end

  defmacro track(value, name) do
    quote do
      result = unquote(value)
      dbug("Value tracked: #{unquote(name)} = #{inspect(result)}")
      result
    end
  end

  @doc """
  Check if debug is enabled based on application config.
  """
  def get_debug_enabled(opts) do
    env_enabled = Application.get_env(:ex_dbug, :enabled, true)
    Keyword.get(opts, :enabled, env_enabled)
  end

  @doc """
  Merge options from app config, defaults, and module opts.
  """
  def merge_options(opts) do
    defaults = [
      max_depth: 3,
      include_timing: true,
      include_stack: true
    ]

    app_config = Application.get_all_env(:ex_dbug)
    Keyword.merge(defaults, app_config) |> Keyword.merge(opts)
  end

  @doc """
  Format output by prefixing with [Namespace].
  """
  def format_output(message, context) when is_binary(context) do
    "[#{context}] #{message}"
  end

  @doc """
  Logging logic:
  We determine if we should log by checking:
  1. If the level is allowed
  2. If the context matches DEBUG patterns
  """
  def log(level, message, opts, context) when level in [:debug, :error] do
    if should_log?(level, opts, context) do
      formatted = format_output(message, context)

      case level do
        :debug -> Logger.debug(formatted)
        :error -> Logger.error(formatted)
      end
    end
  end

  @doc false
  def should_log?(level, opts, context) do
    debug_levels = opts[:levels] || [:debug, :error]
    level_allowed = level in debug_levels
    pattern_match = namespace_enabled?(context)

    level_allowed and pattern_match
  end

  @doc """
  Check if a given namespace (context) is enabled by the DEBUG environment variable.
  If DEBUG is unset or empty, default to enabling everything if :enabled is true,
  otherwise no logging.
  """
  def namespace_enabled?(context) do
    patterns = parse_debug_env()
    matches_namespace?(context, patterns)
  end

  @doc """
  Parse the DEBUG environment variable for enable/disable patterns.

  Returns a tuple {includes, excludes}, where includes and excludes are lists of patterns.
  A pattern can have wildcards (*).
  """
  def parse_debug_env do
    debug_val = System.get_env("DEBUG", "")
    # Cache parsed patterns in ETS or application env if desired for performance.
    # For simplicity, parse each time. For efficiency, we could memoize.
    parse_patterns(debug_val)
  end

  @doc false
  def parse_patterns(string) when is_binary(string) do
    # Patterns separated by comma or space
    raw = String.split(string, [",", " "], trim: true)

    {includes, excludes} =
      Enum.reduce(raw, {[], []}, fn pattern, {inc, exc} ->
        pattern = String.trim(pattern)

        cond do
          pattern == "" ->
            {inc, exc}

          String.starts_with?(pattern, "-") ->
            # excluded pattern
            {inc, [String.trim_leading(pattern, "-") | exc]}

          true ->
            # included pattern
            {[pattern | inc], exc}
        end
      end)

    {Enum.reverse(includes), Enum.reverse(excludes)}
  end

  @doc """
  Check if a namespace matches any of the included patterns and is not excluded.
  If no patterns are set, default to enable if the library is enabled.
  """
  def matches_namespace?(namespace, {includes, excludes}) do
    # If DEBUG is empty (no includes and no excludes), default is to match all if enabled
    cond do
      includes == [] and excludes == [] ->
        # If user hasn't set DEBUG, we either show all or none depending on config
        # We'll assume showing all is fine if :enabled is true
        true

      # If includes are specified, namespace must match at least one
      true ->
        included = includes == [] or Enum.any?(includes, &wildcard_match?(namespace, &1))
        excluded = Enum.any?(excludes, &wildcard_match?(namespace, &1))
        included and not excluded
    end
  end

  @doc """
  Perform a simple wildcard match.

  * matches any sequence of characters.
  """
  def wildcard_match?(string, pattern) do
    # Convert pattern into a regex, replacing * with .*
    # Escape regex metacharacters in pattern except for *
    regex_pattern =
      pattern
      |> Regex.escape()
      |> String.replace("\\*", ".*")

    Regex.match?(Regex.compile!("^" <> regex_pattern <> "$"), string)
  end
end
