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

def profile_methods(*methods)
  methods.flatten.each do |method_desc|
    klass_name, mode, method_name = method_desc.split(/([.#])/)
    klass = klass_name.safe_constantize

    begin
      if klass && mode == "."
        ::Rack::MiniProfiler.profile_singleton_method(klass, method_name) { |a| method_desc }
      elsif klass
        ::Rack::MiniProfiler.profile_method(klass, method_name) { |a| method_desc }
      else
        puts "Can not find class: #{klass} (#{method_desc})"
      end
    rescue
#        puts "Can not bind: #{method_desc}"
    end
  end
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
