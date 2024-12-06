defmodule ExDbugTest do
  use ExUnit.Case
  doctest ExDbug

  # Import ExDbug for testing
  use ExDbug

  # Test the debug macro
  test "debug macro logs messages" do
    # Capture log output
    log =
      ExUnit.CaptureLog.capture_log(fn ->
        dbug("Test debug message")
      end)

    # Assert that the log contains the expected message
    assert log =~ "Test debug message"
    assert log =~ "[ExDbugTest"
  end

  # Test the error macro
  test "error macro logs error messages" do
    log =
      ExUnit.CaptureLog.capture_log(fn ->
        error("Test error message")
      end)

    assert log =~ "Test error message"
    assert log =~ "[ExDbugTest"
  end

  # Test the track macro
  test "track macro logs and returns the value" do
    log =
      ExUnit.CaptureLog.capture_log(fn ->
        result = track(1 + 2, "addition")
        assert result == 3
      end)

    assert log =~ "Value tracked: addition = 3"
  end

  # Test configuration options
  test "configuration options are applied" do
    # This test assumes that the default configuration is used
    # You may need to adjust this based on your actual configuration
    assert ExDbug.get_debug_enabled([]) == true

    options = ExDbug.merge_options([])
    assert Keyword.get(options, :max_depth) == 3
    assert Keyword.get(options, :include_timing) == true
    assert Keyword.get(options, :include_stack) == true
  end

  # Test caller information
  test "get_caller returns correct information" do
    caller = ExDbug.get_caller(__ENV__)
    assert length(caller) == 2
    assert List.first(caller) == "ExDbugTest"
    assert is_binary(List.last(caller))
  end

  # Test output formatting
  test "format_output formats message correctly" do
    formatted = ExDbug.format_output("Test message", ["Module", "function"])
    assert formatted == "[Module.function] Test message"
  end

  # Test logging behavior
  test "log function respects configuration" do
    log =
      ExUnit.CaptureLog.capture_log(fn ->
        ExDbug.log(:debug, "Test log message", levels: [:debug], env: [:test])
      end)

    assert log =~ "Test log message"

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        ExDbug.log(:error, "Test error message", levels: [:error], env: [:test])
      end)

    assert log =~ "Test error message"

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        ExDbug.log(:debug, "Should not log", levels: [:error], env: [:test])
      end)

    assert log == ""
  end
end
