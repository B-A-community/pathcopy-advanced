# frozen_string_literal: true

module BACommunity
  module PathCopyAdvanced
    PLUGIN_NAME = 'PathCopy Advanced'
    VERSION     = '1.0.0'

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

    # Один список режимов на группу: по нему Lang.labels строит подписи, а
    # меню и панель берут готовый хэш - режим добавляется в одном месте и
    # перевод нигде не забывается.
    MODE_LISTS = {
      distribution: DISTRIBUTION_MODES,
      orientation:  ORIENTATION_MODES,
      align:        ALIGN_MODES,
      anchor:       ANCHOR_MODES,
      facing:       FACING_MODES,
      rail_align:   RAIL_ALIGN_MODES,
      rail_shape:   RAIL_SHAPES
    }.freeze

    LABEL_PREFIX = {
      distribution: 'dist', orientation: 'orient', align: 'align', anchor: 'anchor',
      facing: 'facing', rail_align: 'railalign', rail_shape: 'railshape'
    }.freeze








    # Preview colors.
    COLOR_PATH    = Sketchup::Color.new(0, 140, 255)
    COLOR_PREVIEW = Sketchup::Color.new(20, 170, 90)
    COLOR_MARKER  = Sketchup::Color.new(230, 90, 30)
  end
end
