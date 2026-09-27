# frozen_string_literal: true

module BACommunity
  module PathCopyAdvanced
    PLUGIN_NAME = 'PathCopy Advanced'
    VERSION     = '0.5.0'

    # Geometric tolerance, in inches (SketchUp's internal unit).
    # SketchUp itself collapses geometry below 0.001", so we stay an order below.
    TOLERANCE = 1.0e-4

    # Hard ceiling on generated copies. Guards against the classic
    # "typed 0.001 as spacing, SketchUp froze forever" failure.
    MAX_COPIES = 20_000

    # A vertex whose two segments meet at less than this is treated as a bend
    # in a smooth curve (tangent blended); at or above it, a corner (the copy
    # follows the segment leaving the vertex, like a fence post).
    SMOOTH_CORNER_COS = Math.cos(45.0 * Math::PI / 180.0)

    # Above this many placements the preview degrades from wireframe boxes
    # to plain markers, so dragging stays interactive on long paths.
    PREVIEW_BOX_LIMIT = 250

    DISTRIBUTION_MODES = %i[spacing count fit segments vertices].freeze
    ORIENTATION_MODES  = %i[flat tangent3d planar none].freeze
    ALIGN_MODES        = %i[start center end].freeze
    FACING_MODES       = %i[auto outward inward].freeze
    ANCHOR_MODES       = %i[origin center bottom].freeze
    RAIL_SHAPES        = %i[rect round].freeze
    RAIL_ALIGN_MODES   = %i[center outward inward].freeze

    # Подписи на русском: интерфейс плагинов B&A русский (design/designcode.md).
    DISTRIBUTION_LABELS = {
      spacing:  'Шаг',
      count:    'Количество',
      fit:      'Подгонка шага',
      segments: 'Подгонка по сегментам',
      vertices: 'По вершинам'
    }.freeze

    ORIENTATION_LABELS = {
      flat:      'По пути, в плане',
      tangent3d: 'По пути, в 3D',
      planar:    'По плоскости пути',
      none:      'Не поворачивать'
    }.freeze

    ANCHOR_LABELS = {
      origin: 'Начало координат объекта',
      center: 'Центр габаритов',
      bottom: 'Низ габаритов'
    }.freeze

    FACING_LABELS = {
      auto:    'Как нарисовано',
      outward: 'Наружу',
      inward:  'Внутрь'
    }.freeze

    RAIL_SHAPE_LABELS = {
      rect:  'Прямоугольное',
      round: 'Круглое'
    }.freeze

    RAIL_ALIGN_LABELS = {
      center:  'По центру',
      outward: 'Наружу',
      inward:  'Внутрь'
    }.freeze

    ALIGN_LABELS = {
      start:  'От начала',
      center: 'По центру',
      end:    'От конца'
    }.freeze

    # Preview colors.
    COLOR_PATH    = Sketchup::Color.new(0, 140, 255)
    COLOR_PREVIEW = Sketchup::Color.new(20, 170, 90)
    COLOR_MARKER  = Sketchup::Color.new(230, 90, 30)
  end
end
