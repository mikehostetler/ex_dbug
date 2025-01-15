defmodule ExDbug.Decorators do
  use Decorator.Define,
    dbug: 0,
    dbug: 1

  require Logger

  def dbug(body, context) do
    quote do
      if ExDbug.enabled?(__MODULE__) do
        result = unquote(body)

        metadata = %{
          module: __MODULE__,
          function: unquote(context.name),
          arity: unquote(context.arity)
        }

        ExDbug.log(
          :debug,
          "#{unquote(context.name)}/#{unquote(context.arity)} called",
          metadata,
          __MODULE__
        )

        result
      else
        unquote(body)
      end
    end
  end

  def dbug(opts, body, context) do
    quote do
      if ExDbug.enabled?(__MODULE__, unquote(opts)) do
        result = unquote(body)

        metadata =
          Map.merge(
            %{
              module: __MODULE__,
              function: unquote(context.name),
              arity: unquote(context.arity)
            },
            Enum.into(unquote(opts), %{})
          )

        ExDbug.log(
          :debug,
          "#{unquote(context.name)}/#{unquote(context.arity)} called",
          metadata,
          __MODULE__
        )

        result
      else
        unquote(body)
      end
    end
  end
end
