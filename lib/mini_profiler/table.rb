module MiniProfiler
  class Table
    # @return [Integer] number of characters wide for the timing fields
    attr_accessor :width
    attr_reader   :fmt_h, :fmt_d

    def handle_width(phrases)
      widths = Array.wrap(phrases).map do |phrase|
        f_to_s(phrase).size
      end + [width, 0]

      @width = widths.compact.max
      @fmt_h = fmt(':')
      @fmt_d = fmt
    end

    def print_header
      print_line(0, "@", "ms", "ms-", "sql", "sqlms", "sqlrows", "comments")
    end

    def print_dashes
      d = "---"
      print_line(0, d, d, d, d, d, d, d)
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

      "| " + (" %*s#{spacer}|" * durations) + # offset, duration, child duration
        "%5s#{spacer}| %*s#{spacer}| %8s#{spacer}|" + #sql count, sql duration, sql row count
        "#{spacer == ' ' ? "`" : " "}%s%s#{spacer == ' ' ? "`" : ""}" #pading, comment
    end

    @@padding = Hash.new { |hash, key| hash[key] = "." * key.to_i }
    def padded(count)
      @@padding[count]
    end

    def print_heading(depth, phrase)
      print_line(depth, nil, nil, nil, nil, nil, nil, phrase)
    end

    def print_line(depth, offset = nil,
                   duration, child_duration,
                   sql_count, sql_duration, sql_row_count, 
                   phrase)
      offset = f_to_s(offset)
      duration = f_to_s(duration)
      child_duration = f_to_s(child_duration)
      sql_duration = z_to_s(sql_duration)
      phrase = phrase.gsub("executing ","") if phrase
      sql_count = z_to_s(sql_count, 0)
      sql_row_count = z_to_s(sql_row_count, 0)

      data = []
      data += [width, offset] if display_offset
      data += [width, duration]
      data += [width, child_duration] if display_children
      data += [sql_count, width, sql_duration, sql_row_count] + [padded(depth)]
      data += [phrase]
      puts (offset == "---" ? fmt_h : fmt_d) % data
    end
  end
end
