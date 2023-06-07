require "forwardable"

module CliMiniProfiler
  class Printer
    extend Forwardable
    attr_accessor :display_children

    attr_accessor :display_sql
    attr_accessor :sql_filter
    attr_accessor :display_trivial
    attr_accessor :display_trace
    attr_accessor :display_cache
    attr_accessor :collapse

    attr_accessor :aggressive_dedup
    attr_accessor :dedup
    attr_accessor :shorten
    # @return [Boolean] true to skip the first record for averages - often the first record is an outlier
    attr_accessor :skip_first

    def initialize
      @display_offset = false
      @display_sql = false
      @display_children = false
      @collapse = []
      @table = CliMiniProfiler::Table.new
      #@sql_filter = /select *"vms"./i
    end

    # would have prefered keeping this as a string or regex
    # but the complexity of collapsing spaces got to a block
    def sql_filter=(val)
      if val.nil? || val == "" || val == false
        @sql_filter = nil
      else
        val = /#{clean_sql(val, prune_quotes: true)}/i
        @sql_filter = ->(x) { clean_sql(x, prune_quotes: true) =~ val }
      end
    end

    def fix_config
      @display_sql = true if @display_trace || @sql_filter || @aggressive_dedup || @shorten
      @display_children = true if @display_sql
      self
    end

    def_delegators :@table, :display_offset, :display_offset=
    def_delegators :@table, :display_stats, :display_stats=

    # internal:
    def_delegators :@table, :handle_width, :print_header, :print_subheader, :print_line, :print_dashes
    def_delegators :@table, :f_to_s

    def collapse=(val)
      @collapse = val.kind_of?(String) ? val.split(",") : val
    end

    def print_page(page, stat)
      query_count, row_count = child_sql_counts(page.root)

      print_line(0, 0.0, page.duration_ms, 0, query_count, page.duration_ms_in_sql, row_count, page[:name],
        stat && stat.memsize_of_all, stat && stat.total_objects, stat && stat.freed_objects?)
      collapse_nodes(page.root[:children], collapse) unless collapse.empty?
      print_node(page.root) if display_children
    end

    def collapse_nodes(children, collapse)
      return unless children
      children.each do |child|
        if collapse.detect { |c| child.name =~ /#{c}/ }
          merge_children(child)
        else
          collapse_nodes(child[:children], collapse)
        end
      end
    end

    # @param page_groups [Array<Page>,Array<Array<Page>>]
    def print_group(page_groups, stats = nil)
      pages = page_groups.flatten
      page_groups = [page_groups] unless page_groups.first.kind_of?(Array)

      handle_width(pages.map(&:duration_ms))
      handle_width(pages.map(&:duration_ms_in_sql))

      # hack
      stat = stats && stats.first

      page_groups.each do |partitions|
        if page_groups.size > 1
          puts "======"
          puts "#{partitions.first[:name]}"
          puts "======"
          puts
        end
        print_header
        print_dashes unless (display_children || display_sql)

        partitions.each do |page|
          print_dashes if (display_children || display_sql)
          print_page(page, stat)
        end

        if partitions.size > 2
          print_dashes
          print_averages(skip_first ? partitions[1..-1] : partitions)
        end
      end

      if stat && stat.total_freed_objects != 0
        puts "* Memory usage does not reflect #{f_to_s(stat.total_freed_objects, 0)} freed objects. "
      end
    end

    def print_averages(pages)
      duration = avg(pages, &:duration_ms)
      counts = pages.map { |page| child_sql_counts(page) }
      query_times = avg(pages, &:duration_ms_in_sql)
      query_count = avg(counts, &:first)
      query_rows = avg(counts, &:last)
      print_line(0, nil, duration, nil, query_count, query_times, query_rows, "avg")
    end

    private

    def print_node(root)
      all_nodes(root, !display_trivial) do |node, _|
        query_count, query_rows = count_sql(node) #if !display_sql # unsure
        query_count = "(#{query_count})" if display_sql && query_count > 0

        print_line(node[:depth], node[:start_milliseconds],
                   node[:duration_milliseconds], node[:duration_without_children_milliseconds],
                   query_count, node[:sql_timings_duration_milliseconds], query_rows,
                   node[:name].try(:strip)) unless node[:name] =~ %r{http://:}
        print_sqls(node[:sql_timings], node) if display_sql
      end
    end

    def trivial(node)
      node[:trivial_duration_threshold_milliseconds] &&
      node[:duration_milliseconds] < node[:trivial_duration_threshold_milliseconds] &&
      node[:sql_timings].size == 0
    end

    def print_sqls(snodes, node)
      # remove cached nodes
      snodes = snodes.select { |snode| !cached_result?(snode) } unless display_cache
      snodes.each do |snode|
        snode[:formatted_command_string] = clean_sql(snode[:formatted_command_string], prune_quotes: true)
        snode[:summary] = summarize_sql_cmd(snode[:formatted_command_string], snode[:parameters], !aggressive_dedup)
        # unsure:
        snode[:formatted_command_string] += " " + fix_params(snode[:parameters]).map(&:second).inspect if snode[:parameters]
      end

      snodes = dedup_sql(snodes, aggressive_dedup) if dedup || aggressive_dedup
      snodes = snodes.select { |snode| sql_filter.call(snode[:formatted_command_string]) } if sql_filter
      snodes.each do |snode|
        print_sql(snode, node[:depth] + 1)
        print_trace(snode[:stack_trace_snippet], node[:depth]) if display_trace
        # ? snode[:is_duplicate]
      end
    end

    def print_sql(snode, depth)
      start_ms = snode[:start_milliseconds]
      duration = snode[:duration_milliseconds] #.round(1) amount of time to fetch all nodes?
      duration_f = snode[:first_fetch_duration_milliseconds] # amount of time to fetch first node
      cached = cached_result?(snode)
      row_count = snode[:row_count] # # rows returned
      summary  = shorten ? snode[:summary] : snode[:formatted_command_string] # shortened sql (custom)
      # why is this sometimes 0?
      count    = snode[:count] || 1 # # times this was run (custom)

      # print_line(depth, start_ms, cached ? nil : duration, nil, count, cached ? duration : duration_f , cached ? "(#{row_count})" : row_count, summary)
      print_line(depth, start_ms, duration_f ? duration : nil, nil, count, duration_f || duration, cached ? "(#{row_count})" : row_count, summary)
    end

    def clean_sql(sql, prune_quotes: false)
      sql = sql.gsub(/ +/, ' ').gsub("&quot;", "\"").gsub("&#39;", "'").gsub("&lt;", '<').gsub("&gt;", '<')
      sql = sql.tr("\"", '') if prune_quotes
      sql
    end

    def print_trace(trace, depth)
      return if trace.tr("\n ",'').size == 0
      print_subheader(depth, "TRACE:")
      trace.split("\n").each do |t|
        # put in spacing so url linking works
        t = t.gsub("`", "'").gsub(":in '", " in '")
        print_subheader(depth + 1, t)
      end
    end

    def child_sql_counts(root)
      all_nodes(root, false, [0, 0], &method(:count_sql))
    end

    def count_sql(node, tgt = [0, 0])
      timings = node[:sql_timings] || return
      # get rid of cached nodes (will get a little false positive as queries w/ 0.000s will be thrown out)
      timings = timings.select { |snode| !cached_result?(snode) }
      tgt[0] += timings.size
      tgt[1] += timings.map {|timing| timing[:row_count].to_i }.sum
      tgt
    end

    def cached_result?(snode)
      duration_f = snode[:first_fetch_duration_milliseconds] # amount of time to fetch first node
      duration_f.nil? || duration_f < 0.001
    end

    def summarize_sql_cmd(sql, params, include_count = true)
      return "SCHEMA #{$1}" if sql =~ /pg_attribute a.*'"?([^'"]*)"?'::regclass/

      sql =~ /^[\n\t ]*(SELECT|UPDATE|DELETE|INSERT)/i #delete from insert into
      operation = $1.try(:upcase)

      case operation
      when "SELECT"
        summary = sql.split("FROM").first[0..100]
      when "INSERT"
        #sql.split(/VALUES/).first
        summary = sql.split("(").first[0..100]
      when "UPDATE", "INSERT"
        segment = sql.split(/WHERE/).first
        # may want to cut off at "SET"
        summary = segment.gsub!(/= *('[^\']*'|\$?[0-9.]*)/) { x = $1 ; x = ".{#{x.length}}" if x.length > 20 ; "= #{x.split("\n").first}"} || segment
        summary = summary[0..100]
      else # "DELETE|BEGIN|COMMIT|ROLLBACK
        summary = sql
      end
      if params && !shorten
        summary += " "
        summary += fix_params(params).map(&:second).inspect.to_s[0..20]
      end
      if include_count
        count = size_sql(sql, params)
        summary += " -- [#{count}]" if count > 10
      end
      summary.gsub!(/^[\n\t ]*([A-Z]+)[\n\t ]+/) { "#{$1} " }# remove opening whitespace
      # not sure if removing newlines in values (e.g. yaml) is good
      summary.gsub!(/[\n\t ]+/,' ')
      summary 
    end

    def size_sql(sql, params)
      sql.size + (params.nil? ? 0 : params.map { |param| param.last.inspect.size }.sum)
    end

    def fix_params(params)
      return unless params
      params.map do |param|
        val = case param.last
              when 'f'
                'false'
              when 't'
                'true'
              when nil
                'null'
              else
                param.last.to_s
              end
        if val.length > 20
          val = val[0..20] + "...[#{val.length}]"
        end
        [param.first, param.last]
      end
    end

    # loop through all children
    def all_nodes(node, skip_trivial = false, tgt = nil, &block)
      # TODO: remove from here - use prune instead (only used in print_node)
      return if skip_trivial && trivial(node)
      yield node, tgt
      node[:children].each { |c| all_nodes(c, skip_trivial, tgt, &block) } if node[:children]
      tgt
    end

    # take all sql calls from children, and merge into parent
    # TODO: only_same
    def merge_children(parent, target = parent)
      parent[:children].each do |child|
        target[:sql_timings] += child[:sql_timings]
        target[:duration_ms_in_sql] += child[:duration_ms_in_sql] if child[:duration_ms_in_sql]
        target[:sql_timings_duration_milliseconds] += child[:sql_timings_duration_milliseconds] if child[:sql_timings_duration_milliseconds]
        target[:row_count] = target[:row_count].to_i + child[:row_count].to_i if child[:row_count]
        merge_children(child, target)
      end
      parent[:children] = []
    end

    # used by dedup_sql to merge multiple sql timer nodes
    def summarize_sql_nodes(snodes)
      summary = snodes.first
      summary[:count] = snodes.size
      null_or_summary(summary, snodes, :first_fetch_duration_milliseconds)
      null_or_summary(summary, snodes, :row_count)
      null_or_summary(summary, snodes, :duration_milliseconds)
      summary
    end

    def null_or_summary(summary, snodes, key)
      values = snodes.map { |s| s[key] }.compact
      summary[key] = values.sum if values.size > 0
    end

    def dedup_sql(snodes, aggressive = false)
      return snodes if snodes.nil? || snodes.size <= 1

      snodes.group_by { |snode | aggressive ? snode[:summary] : [snode[:formatted_command_string], snode[:parameters]] }.values
        .map do |dups|
          summarize_sql_nodes(dups)
        end
    end

    # string manipulation

    def avg(nodes, &block)
      nodes.blank? ? 0 : (nodes.map(&block).sum / nodes.length)
    end
  end
end
