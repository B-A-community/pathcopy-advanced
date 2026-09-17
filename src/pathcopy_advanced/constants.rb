# frozen_string_literal: true

module BACommunity
  module PathCopyAdvanced
    PLUGIN_NAME = 'PathCopy Advanced'
    VERSION     = '0.3.0'

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

    DISTRIBUTION_LABELS = {
      spacing:  'Spacing',
      count:    'Count',
      fit:      'Fit spacing',
      segments: 'Fit per segment',
      vertices: 'Vertices'
    }.freeze

    ORIENTATION_LABELS = {
      flat:      'Follow path (flat)',
      tangent3d: 'Follow path (3D)',
      planar:    'Follow path plane',
      none:      'Keep orientation'
    }.freeze

    ANCHOR_LABELS = {
      origin: 'Object origin',
      center: 'Bounds center',
      bottom: 'Bounds bottom center'
    }.freeze

    FACING_LABELS = {
      auto:    'As drawn',
      outward: 'Face outward',
      inward:  'Face inward'
    }.freeze

    ALIGN_LABELS = {
      start:  'From start',
      center: 'Centered',
      end:    'From end'
    }.freeze

    # Preview colors.
    COLOR_PATH    = Sketchup::Color.new(0, 140, 255)
    COLOR_PREVIEW = Sketchup::Color.new(20, 170, 90)
    COLOR_MARKER  = Sketchup::Color.new(230, 90, 30)
  end
end
