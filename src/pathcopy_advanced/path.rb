# frozen_string_literal: true

module BACommunity
  module PathCopyAdvanced
    # An ordered polyline with an arc-length parameterisation.
    #
    # Everything downstream works in "distance along the path" rather than
    # walking edges, which is what let the original plugin drift off the curve
    # and choke on reversed edges.
    class Path
      attr_reader :points, :length, :cumulative

      # @param points [Array<Geom::Point3d>] ordered; a closed path repeats its
      #   first point as the last element.
      #
      # Only positions are kept. Holding the source edges would leave the path
      # pointing at deleted entities the moment the user hits undo.
      def initialize(points, closed: false)
        @points = dedupe(points)
        @closed = closed && @points.size > 2

        @cumulative = [0.0]
        (1...@points.size).each do |i|
          @cumulative << @cumulative[-1] + @points[i - 1].distance(@points[i]).to_f
        end
        @length = @cumulative[-1]
      end

      def closed?
        @closed
      end

      # Same polyline walked the other way: start and end swap, and every
      # tangent flips, which turns the copies around with it.
      def reverse
        Path.new(@points.reverse, closed: @closed)
      end

      def valid?
        @points.size >= 2 && @length > TOLERANCE
      end

      def segment_count
        @points.size - 1
      end

      # Distances along the path at which real vertices sit. For a closed path
      # the duplicated final vertex is dropped by the caller, not here.
      def vertex_distances
        @cumulative.dup
      end

      # @return [Array(Geom::Point3d, Geom::Vector3d)] position and unit tangent
      def sample(distance)
        d = clamp(distance)
        i = segment_index(d)
        a = @points[i]
        b = @points[i + 1]
        span = @cumulative[i + 1] - @cumulative[i]
        t = span > TOLERANCE ? (d - @cumulative[i]) / span : 0.0

        point = Geom::Point3d.new(
          a.x + (b.x - a.x) * t,
          a.y + (b.y - a.y) * t,
          a.z + (b.z - a.z) * t
        )
        [point, tangent_at(i, t)]
      end

      def bounds
        box = Geom::BoundingBox.new
        @points.each { |pt| box.add(pt) }
        box
      end

      private

      def clamp(distance)
        return 0.0 if distance < 0.0
        return @length if distance > @length

        distance
      end

      # Binary search for the segment containing +distance+.
      def segment_index(distance)
        lo = 0
        hi = @cumulative.size - 1
        while hi - lo > 1
          mid = (lo + hi) / 2
          @cumulative[mid] > distance ? hi = mid : lo = mid
        end
        [lo, segment_count - 1].min
      end

      # Exactly on a vertex, the heading depends on how sharp the bend is.
      # A gentle bend (a segmented arc) gets the averaged tangent, so copies do
      # not visibly kink. A real corner gets the segment leaving the vertex -
      # a fence post at a corner sits square to the next rail, not on the
      # bisector. Averaging at corners was the bug where the one copy that
      # landed on a vertex stood at 45 degrees to all its neighbours.
      def tangent_at(index, t)
        current = direction(index)
        return current unless @points.size > 2

        if t < TOLERANCE
          incoming = index.positive? ? direction(index - 1) : (closed? ? direction(segment_count - 1) : nil)
          return current if incoming.nil?

          smooth?(incoming, current) ? blend(incoming, current) : current
        elsif t > 1.0 - TOLERANCE
          outgoing = index < segment_count - 1 ? direction(index + 1) : (closed? ? direction(0) : nil)
          return current if outgoing.nil?

          smooth?(current, outgoing) ? blend(current, outgoing) : outgoing
        else
          current
        end
      end

      def smooth?(a, b)
        a.dot(b) > SMOOTH_CORNER_COS
      end

      def direction(index)
        vec = @points[index + 1] - @points[index]
        vec.length > TOLERANCE ? vec.normalize : Geom::Vector3d.new(1, 0, 0)
      end

      def blend(a, b)
        sum = Geom::Vector3d.new(a.x + b.x, a.y + b.y, a.z + b.z)
        sum.length > TOLERANCE ? sum.normalize : a
      end

      def dedupe(points)
        out = []
        points.each do |pt|
          out << pt if out.empty? || out[-1].distance(pt).to_f > TOLERANCE
        end
        out
      end
    end
  end
end
