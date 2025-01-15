defmodule ExDbug.Compatibility do
  defmacro __using__(opts) do
    quote do
      import ExDbug.Compatibility
      require Logger

      @debug_opts ExDbug.merge_options(unquote(opts))
      @context Keyword.get(unquote(opts), :context, __MODULE__) |> to_string()

      Process.put(:ex_dbug_opts, @debug_opts)
    end
  end

  defmacro dbug(message, metadata \\ []) do
    quote bind_quoted: [message: message, metadata: metadata] do
      if ExDbug.enabled?(__MODULE__) do
        ExDbug.log(:debug, message, metadata, @context)
      end
    end
  end

  defmacro error(message, metadata \\ []) do
    quote bind_quoted: [message: message, metadata: metadata] do
      if ExDbug.enabled?(__MODULE__) do
        ExDbug.log(:error, message, metadata, @context)
      end
    end
  end

  defmacro track(value, name) do
    quote do
      result = unquote(value)

      if ExDbug.enabled?(__MODULE__) do
        ExDbug.log(:debug, "Value tracked: #{unquote(name)} = #{inspect(result)}", [], @context)
      end

      result
    end
  end
end
