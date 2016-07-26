module CliMiniProfiler
  class RackStorage
    def initialize
#      self.type = "redis"
#      self.storage_options="db=2"
    end

    def load(id)
      return id if id.respond_to?(:root)
      id = $1 if id =~ %r{http.*/(?:results\?id=|run-)([^.]*)(?:.html)?$}
      id = id.to_s.tr("\"'[],",'')
      instance.load(id)
    end

    def save(page_struct)
      instance.save(page_struct)
    end

    def type
      config.storage ? config.storage.name.split("::").last : ""
    end

    def type=(kind)
      kind = kind.camelize
      config.storage = ::Rack::MiniProfiler.const_get(kind + "Store") rescue nil ||
                       ::Rack::MiniProfiler.const_get(kind) rescue nil ||
                       raise("not able to find store Rack::MiniProfiler::#{kind} or #{kind}Store")
    end

    def inspect
      {
        :type => config.storage.name,
        :instance => config.storage_instance.class.name,
        :options => storage_options
      }.inspect
    end

    def storage_options
      config.storage_options ? config.storage_options.map {|n, v| "#{n}=#{v}" }.join(",") : ""
    end

    def storage_options=(name_values)
      name_values.split(",").each do |name_value|
        name, value = name_value.split("=")
        opts[name.strip.to_sym] = value.strip
      end
    end

    # instance of storage class
    def instance
      config.storage_instance ||= config.storage.new(config.storage_options)# .tap { |x| puts "datastore: #{x.inspect}"}
    end

    def current(env = {'RACK_MINI_PROFILER_ORIGINAL_SCRIPT_NAME' => "http://localhost:3000"})
      ::Rack::MiniProfiler.create_current(env, config)
    end

    private

    def config
      @config ||= ::Rack::MiniProfiler.config
    end

    def opts
      config.storage_options ||= {}
    end
  end
end
