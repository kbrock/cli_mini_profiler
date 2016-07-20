require "cli_mini_profiler"

def bookend(*args, &block)
  CliMiniProfiler.capture(*args, &block)
end
