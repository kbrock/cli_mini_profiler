module CliMiniProfiler
  # memsize_of_all uses up a bunch of memory and creates a bunch of objects and takes a lot of time
  COLLECT_MEMSIZE = true
  require 'objspace' if COLLECT_MEMSIZE
  class Stat
    attr_accessor :name
    attr_accessor :total_objects, :total_allocated_objects, :total_freed_objects, :old_objects
    attr_accessor :time, :memsize_of_all
    attr_accessor :gc_stat

    # alias code_time time
    def initialize(name = nil)
      @name = name
    end

    def calc
      @time = Time.now
      gc_stat = GC.stat
      @total_allocated_objects = gc_stat[:total_allocated_objects]
      @total_freed_objects     = gc_stat[:total_freed_objects]
      # this seems duplicate. may want to shift to this from total_allocated_objects
      @total_objects           = @total_allocated_objects + @total_freed_objects
      @old_objects             = gc_stat[:old_objects]
      @memsize_of_all          = ObjectSpace.memsize_of_all if COLLECT_MEMSIZE

      self
    end

    def live_objects ; total_allocated_objects - total_freed_objects ; end
    def young_objects ; live_objects - old_objects ; end
    def freed_objects? ; total_freed_objects > 0 ; end
    def code_time ; time ; end
    def delta
      gc_stat = GC.stat
      @time                    = Time.now - @time
      @total_objects           = gc_stat[:total_allocated_objects] + gc_stat[:total_freed_objects] - @total_objects
      @total_freed_objects     = gc_stat[:total_freed_objects]     - @total_freed_objects
      @total_allocated_objects = gc_stat[:total_allocated_objects] - @total_allocated_objects
      @old_objects             = gc_stat[:old_objects]             - @old_objects
      @memsize_of_all          = ObjectSpace.memsize_of_all        - @memsize_of_all if COLLECT_MEMSIZE

      self
    end

    if COLLECT_MEMSIZE
      HEADER_TITLES = %w(mem allocated old freed).freeze
    else
      HEADER_TITLES = %w(allocated old freed).freeze
    end
    FMT = ("|" + HEADER_TITLES.map { "%s" }.join("|") + "|").freeze
    HEADER = (FMT % HEADER_TITLES).freeze
    DASH = (FMT % HEADER_TITLES.map { "---" }).freeze

    def fmt
      FMT
    end

    def header
      HEADER
    end

    def dash
      DASH
    end

    def message
      # "%-34s%5sms %12sb %10sobj/%7s/%8s" %
      # FMT % [
      #   name, colon(code_time),
      #   coma(memsize_of_all),
      #   coma(total_allocated_objects),
      #   coma(old_objects),
      #   coma(total_freed_objects),
      # ]
      if COLLECT_MEMSIZE
        "|#{coma(memsize_of_all)}|#{coma(total_allocated_objects)}|#{coma(old_objects)}|#{coma(total_freed_objects)}|"
      else
        "|#{coma(total_allocated_objects)}|#{coma(old_objects)}|#{coma(total_freed_objects)}|"
      end
    end

    private

    def colon(d) # comes in ms
      return "0" if d.nil? || d == 0
      coma(d.to_f * 1_000).to_i.to_s
    end

    DELIMITER = /(\d)(?=(\d\d\d)+(?!\d))/.freeze
    REPLACEMENT = "\\1,".freeze
    def coma(d)
      # d && d.to_s.gsub(DELIMITER, REPLACEMENT)
      d && d.to_s.gsub(DELIMITER) { |x| "#{x}_" }
    end
  end

  def self.stat(name = nil)
    Stat.new(name).calc
  end

  def self.gc
    GC.start
    self
  end

  def self.track(name = "no name", print_me = true)
    d = Stat.new(name).calc
    yield
    d.delta
  ensure
    if print_me
      puts ["",d.header, d.dash, d.message, "", ""].join("\n")
    end
  end
end
