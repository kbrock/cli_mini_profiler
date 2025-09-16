require "cli_mini_profiler"

# CliMiniProfiler.config(
#   :display_offset => false,
#   :display_children => true,
#   :collapse => "Rendering",
#   :display_sql => true, :shorten => true,

#   :dedup => true, :aggressive_dedup => true, :display_trace => false
# )
def bookend(*args, &block)
  CliMiniProfiler.capture(*args, &block)
end

# def profile_methods(*methods)
#   CLIMiniProfiler.profile(*methods)
# end

def bookendr(*args, &block)
  ActiveRecord::Base.transaction do
    CliMiniProfiler.capture(*args, &block)
    raise ActiveRecord::RecordNotFound
  end
  raise "unexpected success - sorry"
rescue ActiveRecord::Rollback, ActiveRecord::RecordNotFound
  puts "rolledback"
end
