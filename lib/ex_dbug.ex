defmodule ExDbug do
  @moduledoc """
  Advanced debug utility for debugging and analysis.

  ## Configuration

  Can be configured globally in config.exs:

      config :ex_dbug,
        enabled: true,
        log_level: :debug,
        include_timing: true,
        include_stack: true

  Or per-module:

      use ExDbug,
        enabled: true,
        context: :my_feature

  ## Features

  - Automatic value tracking across function calls
  - Performance timing information
  - Stack trace integration
  - Context preservation
  """

  require Logger

  @type debug_opts :: [
          enabled: boolean(),
          context: atom(),
          max_depth: non_neg_integer(),
          include_timing: boolean(),
          include_stack: boolean()
        ]

  defmacro __using__(opts \\ []) do
    enabled = get_debug_enabled(opts)

    if enabled && Mix.env() in [:dev, :test] do
      quote do
        import ExDbug
        require Logger
        require ExDbug

        @debug_opts ExDbug.merge_options(unquote(opts))
        @context Keyword.get(unquote(opts), :context, __MODULE__)

        @before_compile ExDbug
      end
    else
      quote do
        require Logger

        defmacro debug(_, _ \\ [], _ \\ []), do: nil
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

  defmacro debug(message, metadata \\ [], opts \\ []) do
    if Mix.env() in [:dev, :test] do
      quote bind_quoted: [message: message, metadata: metadata, opts: opts] do
        caller = ExDbug.get_caller(__ENV__)
        formatted_output = ExDbug.format_output(message, caller)
        ExDbug.log(:debug, formatted_output, @debug_opts)
      end
    else
      quote do
        nil
      end
    end
  end

  defmacro error(message, metadata \\ [], opts \\ []) do
    if Mix.env() in [:dev, :test] do
      quote bind_quoted: [message: message, metadata: metadata, opts: opts] do
        caller = ExDbug.get_caller(__ENV__)
        formatted_output = ExDbug.format_output(message, caller)
        ExDbug.log(:error, formatted_output, @debug_opts)
      end
    else
      quote do
        nil
      end
    end
  end

  defmacro track(value, name) do
    if Mix.env() in [:dev, :test] do
      quote do
        result = unquote(value)
        debug("Value tracked: #{unquote(name)} = #{inspect(result)}")
        result
      end
    else
      quote do
        unquote(value)
      end
    end
  end

  def get_debug_enabled(opts) do
    env_enabled = Application.get_env(:ex_dbug, :enabled, true)
    Keyword.get(opts, :enabled, env_enabled)
  end

  def merge_options(opts) do
    defaults = [
      max_depth: 3,
      include_timing: true,
      include_stack: true
    ]

    app_config = Application.get_all_env(:ex_dbug)
    Keyword.merge(defaults, app_config) |> Keyword.merge(opts)
  end

  def get_caller(env) do
    module =
      env.module
      |> Module.split()
      |> List.last()
      |> to_string()

    function_name =
      case env.function do
        {name, _arity} -> to_string(name)
        nil -> "unknown"
      end

    [module, function_name]
  end

  def format_output(message, [module, function]) do
    "[#{module}.#{function}] #{message}"
  end

  def log(level, message, opts) when level in [:debug, :error] do
    if should_log?(level, opts) do
      case level do
        :debug -> Logger.debug(message)
        :error -> Logger.error(message)
      end
    end
  end

  defp should_log?(level, opts) do
    debug_levels = opts[:levels] || [:debug, :error]
    env_whitelist = opts[:env] || [:dev, :test]
    level in debug_levels and Mix.env() in env_whitelist
  end
end
