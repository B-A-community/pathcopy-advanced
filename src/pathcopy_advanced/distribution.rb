# frozen_string_literal: true

module BACommunity
  module PathCopyAdvanced
    # Decides *where* along a path copies go, in arc-length space.
    #
    # Returns plain Floats (inches). Nothing here knows about entities or
    # transformations, which makes every mode trivially testable.
    module Distribution
      module_function

      # @param path [Path]
      # @param options [Settings]
      # @return [Array<Float>] distances along the path, ascending
      def distances(path, options)
        return [] unless path.valid?

        from = options.start_offset.to_f
        to   = path.length - options.end_offset.to_f
        span = to - from
        return [] if span < -TOLERANCE

        result =
          case options.distribution
          when :vertices then vertex_distances(path, from, to)
          when :count    then count_distances(path, options, from, span)
          when :fit      then fit_distances(path, options, from, span)
          when :segments then segment_distances(path, options, from, to)
          else                spacing_distances(path, options, from, to, span)
          end

        result.take(MAX_COPIES)
      end

      # --- modes ---------------------------------------------------------

      def vertex_distances(path, from, to)
        list = path.vertex_distances
        list = list[0..-2] if path.closed? && list.size > 1
        list.select { |d| d >= from - TOLERANCE && d <= to + TOLERANCE }
      end

      def count_distances(path, options, from, span)
        n = options.count.to_i.clamp(0, MAX_COPIES)
        return [] if n < 1
        return [from + span / 2.0] if n == 1

        # On a closed loop the last slot coincides with the first, so N copies
        # need N intervals rather than N-1. This is the seam-duplicate bug
        # the original never handled.
        intervals = closed_seam?(path, options) ? n : n - 1
        step = span / intervals
        Array.new(n) { |i| from + i * step }
      end

      def fit_distances(path, options, from, span)
        desired = options.spacing.to_f
        return [] if desired <= TOLERANCE

        intervals = [(span / desired).round, 1].max.clamp(1, MAX_COPIES)
        step = span / intervals
        total = closed_seam?(path, options) ? intervals : intervals + 1
        Array.new(total) { |i| from + i * step }
      end

      # Fence mode: every vertex gets a copy, and the spacing is fitted inside
      # each segment separately. Asked for by the people who will use this for
      # railings - a post that misses a corner is useless.
      def segment_distances(path, options, from, to)
        step = options.spacing.to_f
        return [] if step <= TOLERANCE

        cumulative = path.cumulative
        result = []
        (0...path.segment_count).each do |i|
          start = cumulative[i]
          length = cumulative[i + 1] - start
          next if length <= TOLERANCE

          intervals = [(length / step).round, 1].max.clamp(1, MAX_COPIES)
          (0..intervals).each do |k|
            distance = start + length * k / intervals
            result << distance if result.empty? || (distance - result.last).abs > TOLERANCE
          end
          break if result.size >= MAX_COPIES
        end

        if closed_seam?(path, options) && result.size > 1 && (result.last - path.length).abs < TOLERANCE
          result.pop
        end
        result.select { |d| d >= from - TOLERANCE && d <= to + TOLERANCE }
      end

      def spacing_distances(path, options, from, to, span)
        step = options.spacing.to_f
        return [] if step <= TOLERANCE

        # Capped before the array is built, not after: a spacing of 0.001 on a
        # long path would otherwise ask Ruby for billions of elements.
        intervals = (span / step + TOLERANCE).floor
        return [] if intervals.negative?

        intervals = MAX_COPIES if intervals > MAX_COPIES

        used = intervals * step
        base =
          case options.align
          when :center then from + (span - used) / 2.0
          when :end    then to - used
          else              from
          end

        total = intervals + 1
        # Drop the closing copy only when it actually lands back on the seam.
        total -= 1 if closed_seam?(path, options) && (span - used).abs < TOLERANCE

        Array.new(total) { |i| base + i * step }
      end

      def closed_seam?(path, options)
        path.closed? && options.skip_seam && (options.start_offset.to_f.abs < TOLERANCE) &&
          (options.end_offset.to_f.abs < TOLERANCE)
      end
    end
  end
end
