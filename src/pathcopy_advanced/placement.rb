# frozen_string_literal: true

module BACommunity
  module PathCopyAdvanced
    # Turns distances along a path into world transformations.
    #
    # Every copy is built as:
    #
    #   translate(target) * basis * spin * scale * local
    #
    # where +local+ carries the source object's own rotation and scale (the
    # original plugin threw those away for components) and +basis+ is the frame
    # derived from the path tangent.
    module Placement
      module_function

      # @param path [Path]
      # @param distances [Array<Float>]
      # @param settings [Settings]
      # @param source [Sketchup::Group, Sketchup::ComponentInstance, Array]
      #   one object, or several to alternate between
      # @param index_offset [Integer] how many copies were already placed on
      #   earlier paths, so alternation and flipping stay continuous
      # @return [Array<Geom::Transformation>]
      def transformations(path, distances, settings, source, index_offset: 0)
        sources = Array(source)
        return [] if sources.empty?

        # One local transform per source: alternating between a scaled and an
        # unscaled object must not apply the first one's scale to both.
        locals = sources.map { |item| local_transformation(item, settings.anchor) }
        random = settings.jitter ? Random.new(settings.seed + index_offset) : nil
        previous_basis = nil
        up = settings.orientation == :planar ? path_up(path) : Z_AXIS
        turn_around = loop_flip?(path, settings, up)

        distances.each_with_index.map do |distance, position|
          index = index_offset + position
          local = locals[index % locals.size]
          along = distance
          along += symmetric(random, settings.jitter_along) if random

          point, tangent = path.sample(along)
          basis = orientation_basis(tangent, settings.orientation, previous_basis, up)
          previous_basis = basis

          lateral  = settings.offset_lateral.to_f
          vertical = settings.offset_vertical.to_f
          spin     = settings.extra_angle.to_f
          factor   = 1.0

          if random
            lateral  += symmetric(random, settings.jitter_lateral)
            vertical += symmetric(random, settings.jitter_vertical)
            spin     += symmetric(random, settings.jitter_angle)
            factor   += symmetric(random, settings.jitter_scale)
          end

          spin += 180.0 if turn_around
          spin += 180.0 if settings.alternate_flip && index.odd?
          factor = TOLERANCE if factor < TOLERANCE

          target = offset_point(point, basis, lateral, vertical)

          Geom::Transformation.translation(target) *
            basis *
            Geom::Transformation.rotation(ORIGIN, Z_AXIS, spin.degrees) *
            Geom::Transformation.scaling(factor) *
            local
        end
      end

      # The source's own rotation and scale, with its translation stripped and
      # the chosen anchor moved onto the definition origin.
      def local_transformation(source, anchor_mode = :origin)
        transformation = source.transformation
        rotation_scale = Geom::Transformation.translation(transformation.origin).inverse *
                         transformation

        anchor = anchor_point(source, anchor_mode)
        return rotation_scale if anchor.nil?

        rotation_scale * Geom::Transformation.translation(ORIGIN - anchor)
      end

      # Anchor expressed in the definition's own coordinate space.
      def anchor_point(source, mode)
        return nil if mode == :origin

        definition = source.respond_to?(:definition) ? source.definition : nil
        return nil if definition.nil?

        bounds = definition.bounds
        return nil if bounds.empty?

        center = bounds.center
        case mode
        when :bottom then Geom::Point3d.new(center.x, center.y, bounds.min.z)
        else              center
        end
      end

      # On a closed loop the side an object faces depends on nothing but the
      # direction the loop happened to be drawn in. A requested facing is
      # honoured by turning every copy 180 degrees when the winding disagrees.
      def loop_flip?(path, settings, up = Z_AXIS)
        return false unless path.closed? && settings.facing != :auto
        return false if settings.orientation == :none

        inward = lateral_points_inward?(path, up)
        return false if inward.nil?

        (settings.facing == :inward) != inward
      end

      # Local +Y is up x tangent, the left-hand side of travel. Looking down
      # the frame's up axis, a counter-clockwise loop has its inside on the
      # left; a clockwise one on the right. With a Z-up frame that is "seen
      # from above"; with the path's own plane normal it works for a loop on a
      # wall just as well.
      #
      # Returns nil when the loop has no footprint across that up axis, where
      # "inward" has no meaning for the frame.
      def lateral_points_inward?(path, up = Z_AXIS)
        normal = newell_normal(path.points)
        return nil if normal.nil?

        along = normal.dot(up)
        return nil if along.abs < 1.0e-6

        along.positive?
      end

      # The path's own plane normal, turned to point upward whenever it has an
      # upward component so copies stay upright on a horizontal or sloping
      # path; a vertical path keeps the normal as drawn. Straight or
      # non-planar paths have no usable normal and fall back to Z.
      def path_up(path)
        normal = newell_normal(path.points)
        return Z_AXIS if normal.nil?

        normal.z.negative? ? normal.reverse : normal
      end

      # Newell's method: a plane normal for a polygon that need not be convex,
      # signed by the winding order.
      def newell_normal(points)
        nx = ny = nz = 0.0
        count = points.size
        points.each_with_index do |p, i|
          q = points[(i + 1) % count]
          nx += (p.y - q.y) * (p.z + q.z)
          ny += (p.z - q.z) * (p.x + q.x)
          nz += (p.x - q.x) * (p.y + q.y)
        end
        length = Math.sqrt(nx * nx + ny * ny + nz * nz)
        return nil if length < TOLERANCE

        Geom::Vector3d.new(nx / length, ny / length, nz / length)
      end

      # A right-handed frame whose local X follows the path.
      #
      # +previous+ carries the last usable frame forward, so a strictly vertical
      # segment in flat mode holds the previous heading instead of collapsing to
      # an arbitrary 180 degrees the way the original's flat_angle did.
      def orientation_basis(tangent, mode, previous = nil, up = Z_AXIS)
        case mode
        when :none      then Geom::Transformation.new
        when :tangent3d then basis_3d(tangent)
        when :planar    then basis_planar(tangent, up, previous)
        else                 basis_flat(tangent, previous)
        end
      end

      # X along the path, Z along the path's plane normal, so a loop drawn on
      # a wall carries its copies around in the wall, and any flip happens
      # about that normal rather than about world Z.
      def basis_planar(tangent, up, previous)
        return basis_flat(tangent, previous) if up.parallel?(Z_AXIS)
        return previous || Geom::Transformation.new if tangent.length < TOLERANCE

        x_axis = tangent.normalize
        y_axis = up.cross(x_axis)
        return previous || Geom::Transformation.new if y_axis.length < TOLERANCE

        y_axis.normalize!
        z_axis = x_axis.cross(y_axis)
        Geom::Transformation.axes(ORIGIN, x_axis, y_axis, z_axis)
      end

      def basis_flat(tangent, previous)
        flat = Geom::Vector3d.new(tangent.x, tangent.y, 0)
        return previous || Geom::Transformation.new if flat.length < TOLERANCE

        x_axis = flat.normalize
        y_axis = Z_AXIS.cross(x_axis)
        Geom::Transformation.axes(ORIGIN, x_axis, y_axis, Z_AXIS)
      end

      def basis_3d(tangent)
        return Geom::Transformation.new if tangent.length < TOLERANCE

        x_axis = tangent.normalize
        up = x_axis.parallel?(Z_AXIS) ? Y_AXIS : Z_AXIS
        y_axis = up.cross(x_axis)
        return Geom::Transformation.new if y_axis.length < TOLERANCE

        y_axis.normalize!
        z_axis = x_axis.cross(y_axis)
        Geom::Transformation.axes(ORIGIN, x_axis, y_axis, z_axis)
      end

      # Lateral is +Y of the path frame, vertical is +Z of the path frame.
      def offset_point(point, basis, lateral, vertical)
        return point if lateral.abs < TOLERANCE && vertical.abs < TOLERANCE

        vector = Geom::Vector3d.new(0, lateral, vertical).transform(basis)
        Geom::Point3d.new(point.x + vector.x, point.y + vector.y, point.z + vector.z)
      end

      def symmetric(random, amount)
        value = amount.to_f
        return 0.0 if value.abs < TOLERANCE

        (random.rand * 2.0 - 1.0) * value
      end
    end
  end
end
