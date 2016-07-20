require "cli_mini_profiler/version"

require 'cli_mini_profiler/stat'
require 'cli_mini_profiler/table'
require 'cli_mini_profiler/rack_storage'
require 'cli_mini_profiler/printer'
require 'cli_mini_profiler/profiler'

require 'active_support/all'
require 'rack-mini-profiler'

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
  def self.profile(methods, name = nil)
    methods = [[methods, name]] if name
    methods.each do |klass1, method|
      possible_klasses = [klass1, (klass1.const_get(:ClassMethods) rescue nil)]
      assigned = possible_klasses.compact.map do |klass|
        if klass.respond_to?(method)
          #puts "binding #{"#{klass.name}.#{method}"}"
          ::Rack::MiniProfiler.profile_singleton_method(klass, method) { |a| name || "#{klass.name}.#{method}" }
          true
        elsif klass.method_defined?(method)
          #puts "binding #{"#{klass.name}##{method}"}"
          ::Rack::MiniProfiler.profile_method(klass, method) { |a| name || "#{klass.name}##{method}" }
          true
        end
      end
      puts "Can not bind: #{klass1.name}.#{method}" unless assigned.any?
    end
  end

  def self.profile_method(klass, method)
    ::Rack::MiniProfiler.profile_method(klass, method) { |a| name || "#{klass.name}##{method}" }
  end

  def self.profile_klass(klass, method)
    ::Rack::MiniProfiler.profile_singleton_method(klass, method) { |a| name || "#{klass.name}.#{method}" }
  end
end
