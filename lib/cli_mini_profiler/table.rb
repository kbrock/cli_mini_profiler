module CliMiniProfiler
  class Table
    attr_accessor :display_offset

    attr_accessor :display_children
    attr_accessor :display_stats

    # @return [Integer] number of characters wide for the timing fields
    attr_accessor :width

    attr_reader   :fmt_h, :fmt_d

    def initialize
      @display_offset = false
      @display_children = false
    end

    def handle_width(phrases)
      widths = Array.wrap(phrases).map do |phrase|
        f_to_s(phrase).size
      end + [width, 0]

      @width = widths.compact.max
      @fmt_h = fmt(':')
      @fmt_d = fmt
    end

    def print_header(depth = 0, comment = "objects")
      print_line(depth, "@", "ms", "ms-", "query", "qry ms", "rows", "comments", "bytes", comment)
    end

    def print_subheader(depth = 0, comment = "objects")
      print_line(depth, "","","","","","", comment)
    end

    def print_dashes
      d = "---"
      print_line(0, d, d, d, d, d, d, d, d, d)
    end

    def f_to_s(f, tgt = 1)
      if f.kind_of?(Numeric)
        parts = f.round(tgt).to_s.split('.')
        parts[0].gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
        parts.join('.')
      else
        (f || "")
      end
    end

    def z_to_s(f, tgt = 1)
      f.kind_of?(Numeric) && f.round(tgt) == 0.0 ? nil : f_to_s(f, tgt)
    end
    # actual printing statements

    def fmt(spacer = ' ')
      durations = 1
      durations +=1 if display_children
      durations +=1 if display_offset
      durations +=2 if display_stats

      "| " + (" %*s#{spacer}|" * durations) + # offset, duration, child duration
        "%5s#{spacer}| %*s#{spacer}| %8s#{spacer}|" + #sql count, sql duration, sql row count
        "#{spacer == ' ' ? "`" : " "}%s%s#{spacer == ' ' ? "`" : ""}" #pading, comment
    end

    @@padding = Hash.new { |hash, key| hash[key] = "." * key.to_i + " " }
    def padded(count)
      @@padding[count]
    end

    def print_heading(depth, phrase)
      print_line(depth, nil, nil, nil, nil, nil, nil, phrase)
    end

    def print_line(depth, offset,
                   duration, child_duration,
                   sql_count, sql_duration, sql_row_count, 
                   phrase,
                   memsize_of_all = nil, total_allocated_objects = nil, disclaimer = false)
      offset = f_to_s(offset)
      duration = f_to_s(duration)
      child_duration = f_to_s(child_duration)
      sql_duration = z_to_s(sql_duration)
      phrase = phrase&.gsub(/Executing[a-z ]*:/, "")
      sql_count = z_to_s(sql_count, 0)
      sql_row_count = z_to_s(sql_row_count, 0)
      memsize_of_all = z_to_s(memsize_of_all, 0)
      memsize_of_all += "*" if memsize_of_all && memsize_of_all != "" && disclaimer
      total_allocated_objects = z_to_s(total_allocated_objects, 0)

      data = []
      data += [width, offset] if display_offset
      data += [width, duration]
      # data += [1, width, 1, width] if display_stats
      data += [width, memsize_of_all, width, total_allocated_objects] if display_stats
      data += [width, child_duration] if display_children
      data += [sql_count, width, sql_duration, sql_row_count] + [padded(depth)]
      data += [phrase]
      puts (offset == "---" ? fmt_h : fmt_d) % data
    end
  end
end
