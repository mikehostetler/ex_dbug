defmodule TestContextModule do
  use ExDbug, compatibility_mode: true

  def test_function do
    dbug("Auto context test")
  end
end

defmodule TestDecoratorModule do
  use ExDbug, enabled: true

  @decorate dbug()
  def simple_function(arg) do
    arg * 2
  end

  @decorate dbug(context: :important)
  def important_function(arg) do
    arg + 10
  end
end

defmodule ExDbugTest do
  use ExUnit.Case
  doctest ExDbug

  # Import ExDbug for testing
  use ExDbug, compatibility_mode: true, context: :ExDbugTest

  describe "compatibility mode" do
    test "dbug macro logs messages" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          dbug("Test debug message")
        end)

      assert log =~ "Test debug message"
      assert log =~ "[ExDbugTest]"
    end

    test "error macro logs error messages" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          error("Test error message")
        end)

      assert log =~ "Test error message"
      assert log =~ "[ExDbugTest]"
    end

    test "track macro logs and returns the value" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          result = track(1 + 2, "addition")
          assert result == 3
        end)

      assert log =~ "Value tracked: addition = 3"
    end
  end

  describe "decorator mode" do
    test "simple function decorator logs and returns value" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          result = TestDecoratorModule.simple_function(5)
          assert result == 10
        end)

      assert log =~ "simple_function/1 called"
      assert log =~ "[TestDecoratorModule]"
    end

    test "function decorator with context" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          result = TestDecoratorModule.important_function(5)
          assert result == 15
        end)

      assert log =~ "important_function/1 called"
      assert log =~ "[TestDecoratorModule]"
      assert log =~ "context: :important"
    end
  end

  describe "configuration and compile-time checks" do
    test "configuration options are applied" do
      assert ExDbug.enabled?(TestDecoratorModule)
      assert ExDbug.get_module_config(TestDecoratorModule, :enabled) == true
    end
  end

  describe "caller information and formatting" do
    test "format_output/2 formats message correctly with string context" do
      formatted = ExDbug.format_output("Test message", "MyContext")
      assert formatted == "[MyContext] Test message"
    end
  end

  describe "log function and environment variable filtering" do
    setup do
      # We'll reset the DEBUG environment variable after each test
      original_debug = System.get_env("DEBUG")
      on_exit(fn -> System.put_env("DEBUG", original_debug || "") end)
      :ok
    end

    test "logs message when level is allowed and no DEBUG filtering set" do
      System.put_env("DEBUG", "")

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          ExDbug.log(:debug, "Unfiltered log", [levels: [:debug]], "SomeModule")
        end)

      assert log =~ "Unfiltered log"
    end

    test "does not log if level not in allowed levels" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          ExDbug.log(:debug, "Should not log", [levels: [:error]], "SomeModule")
        end)

      assert log == ""
    end

    test "logs only included pattern if DEBUG is set" do
      System.put_env("DEBUG", "myapp:*")

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          ExDbug.log(:debug, "Should appear", [levels: [:debug]], "myapp:db")
          ExDbug.log(:debug, "Should not appear", [levels: [:debug]], "otherapp:db")
        end)

      assert log =~ "Should appear"
      refute log =~ "Should not appear"
    end

    test "respects excluded patterns with '-' prefix" do
      System.put_env("DEBUG", "*,-myapp:secret")

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          ExDbug.log(:debug, "Allowed log", [levels: [:debug]], "myapp:public")
          ExDbug.log(:debug, "Excluded log", [levels: [:debug]], "myapp:secret")
        end)

      assert log =~ "Allowed log"
      refute log =~ "Excluded log"
    end

    test "wildcard matching works as expected" do
      System.put_env("DEBUG", "payment:*")

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          ExDbug.log(:debug, "Pay init", [levels: [:debug]], "payment:init")
          ExDbug.log(:debug, "Pay proc", [levels: [:debug]], "payment:processing")
          ExDbug.log(:debug, "Unrelated", [levels: [:debug]], "other:stuff")
        end)

      assert log =~ "Pay init"
      assert log =~ "Pay proc"
      refute log =~ "Unrelated"
    end
  end

  describe "metadata handling" do
    test "handles long metadata values with truncation enabled" do
      long_string = String.duplicate("a", 200)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          dbug("Long value test", long_value: long_string)
        end)

      assert log =~ "Long value test"
      assert log =~ "... (truncated)"
    end

    test "respects truncate: false setting" do
      long_string = String.duplicate("a", 200)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          dbug("No truncate test", long_value: long_string, truncate: false)
        end)

      assert log =~ long_string
      refute log =~ "... (truncated)"
    end

    test "handles custom truncate threshold" do
      string = String.duplicate("a", 150)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          dbug("Custom truncate test", value: string, truncate: 50)
        end)

      assert log =~ "... (truncated)"
      refute log =~ string
    end

    test "accepts map metadata" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          dbug("Map metadata test", %{key: "value", count: 42})
        end)

      assert log =~ "Map metadata test"
      assert log =~ "key: \"value\""
      assert log =~ "count: 42"
    end

    test "handles map metadata with truncation" do
      long_string = String.duplicate("a", 200)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          dbug("Map truncation test", %{long_value: long_string})
        end)

      assert log =~ "Map truncation test"
      assert log =~ "... (truncated)"
    end

    test "handles map metadata with custom truncation" do
      string = String.duplicate("a", 150)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          dbug("Map custom truncate", %{value: string, truncate: 50})
        end)

      assert log =~ "Map custom truncate"
      assert log =~ "... (truncated)"
      refute log =~ string
    end
  end

  describe "automatic context detection" do
    test "automatically detects module and function name when no context set" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          TestContextModule.test_function()
        end)

      assert log =~ "[TestContextModule]"
      assert log =~ "Auto context test"
    end

    @debug_msg "Outside function test"
    test "uses module name for module-level logging" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          dbug(@debug_msg)
        end)

      assert log =~ "[ExDbugTest]"
      assert log =~ @debug_msg
    end
  end
end
