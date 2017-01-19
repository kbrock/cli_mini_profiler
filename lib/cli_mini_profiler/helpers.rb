require "cli_mini_profiler"

def bookend(*args, &block)
  CliMiniProfiler.capture(*args, &block)
end

def bookendr(*args, &block)
  ActiveRecord::Base.transaction do
    CliMiniProfiler.capture(*args, &block)
    raise ActiveRecord::RecordNotFound
  end
  raise "unexpected success - sorry"
rescue ActiveRecord::Rollback, ActiveRecord::RecordNotFound
  puts "rolledback"
end
