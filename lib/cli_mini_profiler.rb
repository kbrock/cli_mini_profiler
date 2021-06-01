require 'rack-mini-profiler'
require 'active_support/all'

require "cli_mini_profiler/version"
require 'cli_mini_profiler/stat'
require 'cli_mini_profiler/table'
require 'cli_mini_profiler/rack_storage'
require 'cli_mini_profiler/printer'
require 'cli_mini_profiler/profiler'

module CliMiniProfiler
  def self.config(*args, &block)
    CliMiniProfiler::Profiler.config(*args, &block)
  end

  def self.capture(*args, &block)
    CliMiniProfiler::Profiler.capture(*args, &block)
  end

  # mark a method for capture
  # profile(klass, method_name)
  # profile([[klass, method_name], ...])
  def self.profile(*methods)
    methods.flat_map do |method_desc|
      klass_name, mode, method_name = method_desc.split(/([.#])/)
      klass = klass_name.safe_constantize

      begin
        if klass && mode == "."
          ::Rack::MiniProfiler.profile_singleton_method(klass, method_name) { |a| method_desc }
          true
        elsif klass
          ::Rack::MiniProfiler.profile_method(klass, method_name) { |a| method_desc }
          true
        else
          puts "Can not find class: #{klass} (#{method_desc})"
          false
        end
      rescue
        puts "Can not bind: #{method_desc}"
        false
      end
    end
  end

  def self.profile_method(klass, method)
    ::Rack::MiniProfiler.profile_method(klass, method) { |a| name || "#{klass.name}##{method}" }
  end

  def self.profile_klass(klass, method)
    ::Rack::MiniProfiler.profile_singleton_method(klass, method) { |a| name || "#{klass.name}.#{method}" }
  end
end
