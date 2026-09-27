# frozen_string_literal: true

module BACommunity
  module PathCopyAdvanced
    # Поручень: профиль, протянутый вдоль пути.
    #
    # Свип со срезом на углах (митрой): в каждой вершине сечение лежит в
    # плоскости-биссектрисе, поэтому соседние участки сходятся гранью в грань
    # без разрыва и без нахлёста. SketchUp'овский FollowMe тут не годится —
    # ему нужны настоящие рёбра в модели, а путь у нас может быть продлён,
    # развёрнут и собран из несваренных рёбер.
    #
    # Локальные координаты сечения: u — вбок (влево по ходу), v — вверх.
    module Railing
      ROUND_SEGMENTS = 16

      module_function

      # @return [Sketchup::Group, nil]
      def build(entities, path, settings)
        rings = sections(path, settings)
        return nil if rings.size < 2

        group = entities.add_group
        faces = skin(group.entities, rings, path.closed?)
        if faces.zero?
          group.erase! if group.valid?
          return nil
        end

        smooth_round_edges(group.entities, settings)
        group.name = 'PathCopy — поручень'
        group
      end

      # Сечения по всем вершинам пути, в мировых координатах.
      # @return [Array<Array<Geom::Point3d>>]
      def sections(path, settings)
        return [] unless path.valid? && settings.rail

        points = extended_points(path, settings)
        return [] if points.size < 2

        up = Placement.path_up(path)
        shape = profile(settings, outward_sign(path, up))
        return [] if shape.empty?

        directions = (0...points.size - 1).map { |i| direction(points[i], points[i + 1]) }
        return [] if directions.any?(&:nil?)

        closed = path.closed?
        vertex_count = closed ? points.size - 1 : points.size

        (0...vertex_count).map do |i|
          incoming = closed ? directions[(i - 1) % directions.size] : directions[[i - 1, 0].max]
          outgoing = closed ? directions[i % directions.size] : directions[[i, directions.size - 1].min]
          section_at(points[i], incoming, outgoing, up, shape)
        end.reject(&:empty?)
      end

      # Контур сечения в локальных координатах: [[u, v], ...].
      def profile(settings, outward = 1)
        half_width = settings.rail_width.to_f / 2.0
        half_height = settings.rail_height.to_f / 2.0
        return [] if half_width <= TOLERANCE || half_height <= TOLERANCE

        shift = lateral_shift(settings, half_width, outward)
        # Подъём над линией: путь рисуют по низу, а поручень нужен наверху.
        rise = settings.rail_rise.to_f

        if settings.rail_shape == :round
          (0...ROUND_SEGMENTS).map do |i|
            angle = 2.0 * Math::PI * i / ROUND_SEGMENTS
            [shift + half_width * Math.cos(angle), rise + half_height * Math.sin(angle)]
          end
        else
          [[shift - half_width, rise - half_height], [shift + half_width, rise - half_height],
           [shift + half_width, rise + half_height], [shift - half_width, rise + half_height]]
        end
      end

      # Привязка: по центру профиль сидит на линии, наружу и внутрь — целиком
      # с одной её стороны.
      def lateral_shift(settings, half_width, outward)
        case settings.rail_align
        when :outward then half_width * outward
        when :inward  then -half_width * outward
        else 0.0
        end
      end

      # Куда указывает локальное +Y: на замкнутом контуре наружу — та сторона,
      # где нет внутренней области; на открытом пути «наружу» — левая по ходу.
      def outward_sign(path, up)
        inward = Placement.lateral_points_inward?(path, up)
        return 1.0 if inward.nil?

        inward ? -1.0 : 1.0
      end

      # Концы можно вывести за путь — поручень заходит за крайнюю стойку.
      def extended_points(path, settings)
        points = path.points
        length = settings.rail_extend.to_f
        return points if path.closed? || length <= TOLERANCE || points.size < 2

        head = direction(points[0], points[1])
        tail = direction(points[-2], points[-1])
        return points if head.nil? || tail.nil?

        [move(points[0], head, -length)] + points + [move(points[-1], tail, length)]
      end

      # Сечение в вершине: точки профиля сдвигаются вдоль входящего направления
      # до плоскости-биссектрисы, и стык получается ровным при любом угле.
      def section_at(vertex, incoming, outgoing, up, shape)
        side = up.cross(incoming)
        return [] if side.length < TOLERANCE

        side = side.normalize
        vertical = incoming.cross(side)
        return [] if vertical.length < TOLERANCE

        vertical = vertical.normalize
        normal = bisector(incoming, outgoing)
        along = incoming.dot(normal)

        shape.map do |u, v|
          local = Geom::Vector3d.new(side.x * u + vertical.x * v,
                                     side.y * u + vertical.y * v,
                                     side.z * u + vertical.z * v)
          slide = along.abs < TOLERANCE ? 0.0 : -local.dot(normal) / along
          Geom::Point3d.new(vertex.x + local.x + incoming.x * slide,
                            vertex.y + local.y + incoming.y * slide,
                            vertex.z + local.z + incoming.z * slide)
        end
      end

      # Нормаль плоскости среза. На прямом участке и на концах это само
      # направление пути.
      def bisector(incoming, outgoing)
        sum = Geom::Vector3d.new(incoming.x + outgoing.x, incoming.y + outgoing.y, incoming.z + outgoing.z)
        sum.length < TOLERANCE ? incoming : sum.normalize
      end

      def direction(from, to)
        vector = to - from
        vector.length < TOLERANCE ? nil : vector.normalize
      end

      def move(point, unit, distance)
        Geom::Point3d.new(point.x + unit.x * distance,
                          point.y + unit.y * distance,
                          point.z + unit.z * distance)
      end

      # --- построение граней ---------------------------------------------

      def skin(entities, rings, closed)
        made = 0
        limit = closed ? rings.size : rings.size - 1

        (0...limit).each do |i|
          a = rings[i]
          b = rings[(i + 1) % rings.size]
          next unless a.size == b.size

          a.each_index do |k|
            n = (k + 1) % a.size
            made += 1 if quad(entities, a[k], a[n], b[n], b[k])
          end
        end

        unless closed
          made += 1 if cap(entities, rings.first.reverse)
          made += 1 if cap(entities, rings.last)
        end
        made
      end

      # Четырёхугольник может оказаться неплоским на изломе — тогда кладём
      # два треугольника.
      def quad(entities, p1, p2, p3, p4)
        entities.add_face(p1, p2, p3, p4)
        true
      rescue StandardError
        made = false
        made = true if triangle(entities, p1, p2, p3)
        made = true if triangle(entities, p1, p3, p4)
        made
      end

      def triangle(entities, p1, p2, p3)
        return false if p1.distance(p2) < TOLERANCE || p2.distance(p3) < TOLERANCE || p3.distance(p1) < TOLERANCE

        entities.add_face(p1, p2, p3)
        true
      rescue StandardError
        false
      end

      def cap(entities, ring)
        return false if ring.size < 3

        entities.add_face(ring)
        true
      rescue StandardError
        false
      end

      # У круглого профиля продольные рёбра сглаживаются, иначе гранёная труба.
      def smooth_round_edges(entities, settings)
        return unless settings.rail_shape == :round

        entities.grep(Sketchup::Edge).each do |edge|
          next unless edge.faces.size == 2

          edge.soft = true
          edge.smooth = true
        end
      rescue StandardError
        nil
      end
    end
  end
end
