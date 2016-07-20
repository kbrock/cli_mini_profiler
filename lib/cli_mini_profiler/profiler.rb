require 'objspace'
require 'singleton'
require 'json'

module CliMiniProfiler
  class Profiler
    include Singleton

    def initialize
    end

    def self.capture(name = "no name", count = 1, options = {}, &block)
      name,  options = nil, name  if name.kind_of?(Hash)
      count, options = nil, count if count.kind_of?(Hash)

      name ||= options[:name] || "no name"
      count ||= options[:count] || 1
      gc_mode = options[:gc] && options[:gc] || false
      gc_mode = gc_mode.to_sym if gc_mode.kind_of?(String)

      gp = instance

      if gc_mode == :disable
        GC.disable
      elsif gc_mode != false
        GC.start
      end

      # [[gen_perf_num, stat]]
      xs = count.times.collect do |i|
        gp.capture("#{name}-#{i+1}", &block)
      end
      gp.print_xs(xs)
      xs.map(&:first) #process ids
    ensure
      GC.enable if gc_mode == :disable
    end

      # rollback = !options[:rollback].nil? && options[:rollback] != false
      # if rollback
      #   xs = count.times.collect do |i|
      #     x_s = nil
      #     begin
      #       Vm.transaction do
      #         x_s = gp.capture("#{name}-#{i+1}", &block)
      #         raise "rolling back transaction"
      #       end
      #     rescue => e
      #       raise unless e.message == "rolling back transaction"
      #     end
      #     x_s
      #   end
      # else

    def self.config(name, options = nil)
      name, options = :printer, name if options.nil?
      if options.kind_of?(Hash)
        instance.config(name, options)
      else
        instance.config(name, options)
      end
    end

    def self.print(ids)
      instance.print(Array.wrap(ids))
    end

    def capture(name, options = {})
      # env = {
      # 'PATH_INFO' => 'cli', # method name?
      # 'QUERY_STRING'
      # 'SCRIPT_NAME' => '',
      # 'SERVER_NAME' => 'localhost',
      # 'REQUEST_METHOD'
      # 'SERVER_PORT' => '3000',
      # }
      base_url = options[:base_url] || "http://localhost:3000"
      # base_file = options[:base_file] || defined?(Rails) ? Rails.root.join("public") : "."
      env = {'RACK_MINI_PROFILER_ORIGINAL_SCRIPT_NAME' => base_url}

      page_struct = storage.current(env).page_struct
      #page_struct[:user] = config.user_provider.call(env) # needed?
      page_struct[:name] = name
      d = CliMiniProfiler::Stat.new(name).calc
      yield
      d.delta
      page_struct[:root].record_time(d.time * 1000)

  #    storage.set_unviewed(page_struct[:user], page_struct[:id])
      storage.save(page_struct)
      [page_struct[:id], d]
    ensure
      ::Rack::MiniProfiler.current = nil
    end

    def print(pages, stats = nil)
      pages = Array.wrap(pages).map { |id| storage.load(id) }
      page_groups = pages.group_by { |page| page[:name] =~ /^(.*[^0-9])[0-9]+$/ ; $1 }.values
      printer.print_group(page_groups, stats)
    end

    def print_xs(xs)
      stats = xs.map(&:last)
      x = xs.map(&:first) #process ids
      if true
        print(x, stats)
        puts
      else
        puts
        puts "beer gen_perf #{x}"
      end
      x
    end

    # config

    def printer
      @printer ||= ::CliMiniProfiler::Printer.new.tap do |printer|
        printer.display_children = false
        printer.display_sql = true
        printer.shorten = true
        printer.display_stats = true
      end
    end

    def storage
      @storage ||= ::CliMiniProfiler::RackStorage.new
    end

    def config(obj, params)
      target = public_send(obj)
      if params.kind_of?(Hash)
        params.each { |n, v| target.public_send("#{n}=", v) }
      else
        target.public_send(params)
      end
    end
  end
end
