defmodule ExDbugTest do
  use ExUnit.Case
  doctest ExDbug

  # We only use ExDbug if :enabled => true in config (default).
  # If you need to test compile-time disabling, set config or override in test env.

  # Import ExDbug for testing
  use ExDbug, context: :ExDbugTest

  describe "basic debugging macros" do
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

  describe "configuration and compile-time checks" do
    test "configuration options are applied" do
      assert ExDbug.get_debug_enabled([]) == true

      options = ExDbug.merge_options([])
      assert Keyword.get(options, :max_depth) == 3
      assert Keyword.get(options, :include_timing) == true
      assert Keyword.get(options, :include_stack) == true
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
      # means no patterns set
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
      # Only the 'myapp:*' context is included
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
end
