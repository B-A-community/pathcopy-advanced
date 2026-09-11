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

        distances.each_with_index.map do |distance, position|
          index = index_offset + position
          local = locals[index % locals.size]
          along = distance
          along += symmetric(random, settings.jitter_along) if random

          point, tangent = path.sample(along)
          basis = orientation_basis(tangent, settings.orientation, previous_basis)
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

      # A right-handed frame whose local X follows the path.
      #
      # +previous+ carries the last usable frame forward, so a strictly vertical
      # segment in flat mode holds the previous heading instead of collapsing to
      # an arbitrary 180 degrees the way the original's flat_angle did.
      def orientation_basis(tangent, mode, previous = nil)
        case mode
        when :none      then Geom::Transformation.new
        when :tangent3d then basis_3d(tangent)
        else                 basis_flat(tangent, previous)
        end
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
