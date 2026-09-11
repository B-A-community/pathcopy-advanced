# frozen_string_literal: true
#
# Live checks inside a running SketchUp. Loaded over the MCP bridge:
#   POST :8080/ruby/execute  {"code":"load 'C:/.../tests/live_test.rb'"}
#
# The offline suite proves the arithmetic against a stubbed API. This proves the
# same code against the real one - transformation composition order, Group#copy,
# add_instance, operation nesting - which a stub cannot vouch for.

module PCALive
  REPORT = []
  BASE = Geom::Point3d.new(2000, 0, 0) # clear of whatever is already modelled

  module_function

  def check(name, condition, detail = '')
    REPORT << [condition ? 'PASS' : 'FAIL', name, detail.to_s]
    condition
  end

  def close?(a, b, tolerance = 1.0e-4)
    (a.to_f - b.to_f).abs <= tolerance
  end

  def at(dx, dy, dz = 0)
    Geom::Point3d.new(BASE.x + dx, BASE.y + dy, BASE.z + dz)
  end

  def model
    Sketchup.active_model
  end

  def entities
    model.active_entities
  end

  # A 24 x 8 x 40 marker box, longer in X so a heading change is obvious.
  def marker_definition(name)
    existing = model.definitions[name]
    return existing if existing

    definition = model.definitions.add(name)
    face = definition.entities.add_face(
      Geom::Point3d.new(0, -4, 0), Geom::Point3d.new(24, -4, 0),
      Geom::Point3d.new(24, 4, 0), Geom::Point3d.new(0, 4, 0)
    )
    face.pushpull(40)
    definition
  end

  def run
    REPORT.clear
    $pca_baseline = entities.to_a.dup

    scenario_unwelded_chain
    scenario_curve_and_circle
    scenario_transform_composition
    scenario_source_transform_preserved
    scenario_group_copy
    scenario_orientation_3d
    scenario_anchor
    scenario_single_undo
    scenario_tool_activates

    write_report
  end

  # --- scenarios -------------------------------------------------------

  # add_line creates plain edges with no Curve; this is exactly the case that
  # forced everyone to run Weld before the original plugin.
  def scenario_unwelded_chain
    a = entities.add_line(at(0, 0), at(100, 0))
    entities.add_line(at(100, 0), at(100, 100))
    entities.add_line(at(100, 100), at(250, 100))

    check('add_line really produces no Curve', a.curve.nil?, a.curve.inspect)

    path = BACommunity::PathCopyAdvanced::PathBuilder.from_seed_edge(a)
    check('unwelded chain grows from one picked edge', !path.nil?)
    return unless path

    check('chain has all four points', path.points.size == 4, path.points.size)
    check('chain length is 350', close?(path.length, 350.0), path.length)
    check('chain is open', !path.closed?)
  end

  def scenario_curve_and_circle
    arc_edges = entities.add_arc(at(0, 400), X_AXIS, Z_AXIS, 100, 0, 180.degrees, 24)
    check('add_arc produced a Curve', !arc_edges.first.curve.nil?)

    arc_path = BACommunity::PathCopyAdvanced::PathBuilder.from_seed_edge(arc_edges.first)
    check('arc becomes one open path', arc_path && !arc_path.closed?)
    check('arc length is near pi*r', arc_path && close?(arc_path.length, Math::PI * 100, 1.0),
          arc_path&.length)

    circle_edges = entities.add_circle(at(600, 400), Z_AXIS, 100, 24)
    circle_path = BACommunity::PathCopyAdvanced::PathBuilder.from_seed_edge(circle_edges.first)
    check('circle is detected as closed', circle_path&.closed?)
    check('circle repeats its seam point', circle_path && circle_path.points.size == 25,
          circle_path&.points&.size)

    settings = BACommunity::PathCopyAdvanced::Settings.new
    settings.distribution = :count
    settings.count = 8
    settings.skip_seam = true
    distances = BACommunity::PathCopyAdvanced::Distribution.distances(circle_path, settings)
    check('closed loop gets exactly 8 slots, no seam duplicate', distances.size == 8, distances.size)
  end

  # The one thing a stub can never confirm: that a * b in the real API means
  # "apply b, then a", which is what every transform in Placement assumes.
  def scenario_transform_composition
    translate = Geom::Transformation.translation(Geom::Vector3d.new(100, 0, 0))
    spin = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees)
    combined = translate * spin
    moved = Geom::Point3d.new(10, 0, 0).transform(combined)

    check('transformation composition applies right operand first',
          close?(moved.x, 100) && close?(moved.y, 10), moved.to_a.inspect)

    basis = Geom::Transformation.axes(ORIGIN, Y_AXIS, X_AXIS.reverse, Z_AXIS)
    check('Transformation.axes builds the frame we expect',
          close?(basis.xaxis.x, 0) && close?(basis.xaxis.y, 1), basis.xaxis.to_a.inspect)
  end

  def scenario_source_transform_preserved
    definition = marker_definition('PCA_Marker')
    scaled = Geom::Transformation.scaling(at(0, 800), 2.0) *
             Geom::Transformation.rotation(ORIGIN, Z_AXIS, 0)
    source = entities.add_instance(definition, Geom::Transformation.translation(at(0, 800).clone - ORIGIN))
    source.transformation = Geom::Transformation.new(at(0, 800)) * Geom::Transformation.scaling(2.0)

    entities.add_line(at(0, 900), at(400, 900))
    path_edge = entities.grep(Sketchup::Edge).find do |edge|
      edge.start.position == at(0, 900) || edge.end.position == at(0, 900)
    end
    path = BACommunity::PathCopyAdvanced::PathBuilder.from_seed_edge(path_edge)

    settings = BACommunity::PathCopyAdvanced::Settings.new
    settings.distribution = :count
    settings.count = 5
    settings.orientation = :flat

    distances = BACommunity::PathCopyAdvanced::Distribution.distances(path, settings)
    transformations = BACommunity::PathCopyAdvanced::Placement.transformations(path, distances, settings, source)
    created = BACommunity::PathCopyAdvanced::Copier.run(model, [source], transformations, settings)

    check('five copies were created', created.size == 5, created.size)
    check('copies are ComponentInstances',
          created.all? { |e| e.is_a?(Sketchup::ComponentInstance) })
    # Uniform scale lives in the matrix w term, not in the axis lengths, so
    # xaxis.length reads 1.0 however scaled the instance is. Measure xscale.
    check('component copy keeps its 2x scale',
          created.all? { |e| close?(e.transformation.xscale, 2.0, 1.0e-3) },
          created.map { |e| e.transformation.xscale.round(4) }.inspect)
    check('copies sit on the path',
          created.all? { |e| close?(e.transformation.origin.y, at(0, 900).y, 1.0e-3) },
          created.map { |e| e.transformation.origin.y.round(3) }.inspect)
    check('copies are evenly spread over 400',
          close?(created.first.transformation.origin.x, at(0, 900).x) &&
          close?(created.last.transformation.origin.x, at(400, 900).x),
          [created.first.transformation.origin.x, created.last.transformation.origin.x].inspect)
    check('scaled source did not shift the copies off the path',
          created.all? { |e| close?(e.transformation.origin.z, 0.0, 1.0e-3) })
  end

  def scenario_group_copy
    group = entities.add_group
    face = group.entities.add_face(
      at(0, 1200), at(30, 1200), at(30, 1210), at(0, 1210)
    )
    face.pushpull(30)

    entities.add_line(at(0, 1300), at(300, 1300))
    path_edge = entities.grep(Sketchup::Edge).find do |edge|
      edge.start.position == at(0, 1300) || edge.end.position == at(0, 1300)
    end
    path = BACommunity::PathCopyAdvanced::PathBuilder.from_seed_edge(path_edge)

    settings = BACommunity::PathCopyAdvanced::Settings.new
    settings.distribution = :count
    settings.count = 4
    settings.orientation = :flat
    settings.anchor = :bottom

    distances = BACommunity::PathCopyAdvanced::Distribution.distances(path, settings)
    transformations = BACommunity::PathCopyAdvanced::Placement.transformations(path, distances, settings, group)
    created = BACommunity::PathCopyAdvanced::Copier.run(model, [group], transformations, settings)

    check('group copies are Groups, not instances',
          created.size == 4 && created.all? { |e| e.is_a?(Sketchup::Group) },
          created.map { |e| e.class.to_s }.uniq.inspect)
    # anchor :bottom lands the bounds bottom-centre on the path; the group's
    # own origin deliberately ends up somewhere else.
    check('bottom-anchored group copies rest on the path',
          created.all? { |e| close?(e.bounds.min.z, at(0, 1300).z, 1.0e-2) },
          created.map { |e| e.bounds.min.z.round(3) }.inspect)
    check('bottom-anchored group copies are centred on their path point',
          created.all? { |e| close?((e.bounds.min.y + e.bounds.max.y) / 2.0, at(0, 1300).y, 1.0e-2) },
          created.map { |e| ((e.bounds.min.y + e.bounds.max.y) / 2.0).round(3) }.inspect)
  end

  def scenario_orientation_3d
    entities.add_line(at(0, 1600, 0), at(200, 1600, 200))
    path_edge = entities.grep(Sketchup::Edge).find do |edge|
      edge.start.position == at(0, 1600, 0) || edge.end.position == at(0, 1600, 0)
    end
    path = BACommunity::PathCopyAdvanced::PathBuilder.from_seed_edge(path_edge)
    source = entities.add_instance(marker_definition('PCA_Marker'), Geom::Transformation.new(at(-200, 1600)))

    settings = BACommunity::PathCopyAdvanced::Settings.new
    settings.distribution = :count
    settings.count = 5
    settings.orientation = :tangent3d

    distances = BACommunity::PathCopyAdvanced::Distribution.distances(path, settings)
    transformations = BACommunity::PathCopyAdvanced::Placement.transformations(path, distances, settings, source)
    created = BACommunity::PathCopyAdvanced::Copier.run(model, [source], transformations, settings)

    root = Math.sqrt(0.5)
    axis = created.first.transformation.xaxis
    check('3D orientation tilts the copy with the slope',
          close?(axis.x, root, 1.0e-3) && close?(axis.z, root, 1.0e-3), axis.to_a.inspect)
    check('all five slope copies exist', created.size == 5, created.size)
  end

  def scenario_anchor
    definition = marker_definition('PCA_Marker')
    source = entities.add_instance(definition, Geom::Transformation.new(at(-200, 2000)))

    entities.add_line(at(0, 2000), at(300, 2000))
    path_edge = entities.grep(Sketchup::Edge).find do |edge|
      edge.start.position == at(0, 2000) || edge.end.position == at(0, 2000)
    end
    path = BACommunity::PathCopyAdvanced::PathBuilder.from_seed_edge(path_edge)

    settings = BACommunity::PathCopyAdvanced::Settings.new
    settings.distribution = :count
    settings.count = 1
    settings.orientation = :none
    settings.anchor = :center

    distances = BACommunity::PathCopyAdvanced::Distribution.distances(path, settings)
    transformation = BACommunity::PathCopyAdvanced::Placement
                     .transformations(path, distances, settings, source).first
    centre = definition.bounds.center.transform(transformation)
    target = at(150, 2000)

    check('bounds-centre anchor puts the object centre on the path',
          close?(centre.x, target.x, 1.0e-3) && close?(centre.y, target.y, 1.0e-3) &&
          close?(centre.z, target.z, 1.0e-3),
          "#{centre.to_a.inspect} vs #{target.to_a.inspect}")
  end

  # The headline claim: place, then tweak twice, then ONE undo clears the lot.
  def scenario_single_undo
    definition = marker_definition('PCA_Marker')
    source = entities.add_instance(definition, Geom::Transformation.new(at(-200, 2400)))
    entities.add_line(at(0, 2400), at(400, 2400))
    path_edge = entities.grep(Sketchup::Edge).find do |edge|
      edge.start.position == at(0, 2400) || edge.end.position == at(0, 2400)
    end
    path = BACommunity::PathCopyAdvanced::PathBuilder.from_seed_edge(path_edge)

    settings = BACommunity::PathCopyAdvanced::Settings.new
    settings.distribution = :spacing
    settings.orientation = :flat

    before = entities.length

    settings.spacing = 100.0
    first = place(path, settings, source, merge: false)
    after_first = entities.length

    # Two tweaks, exactly as retyping a value in the measurement box would do.
    BACommunity::PathCopyAdvanced::Copier.erase(model, first)
    settings.spacing = 50.0
    second = place(path, settings, source, merge: true)

    BACommunity::PathCopyAdvanced::Copier.erase(model, second)
    settings.spacing = 80.0
    third = place(path, settings, source, merge: true)
    after_tweaks = entities.length

    check('first run placed 5 copies at 100', first.size == 5, first.size)
    check('final tweak placed 6 copies at 80', third.size == 6, third.size)
    check('entity count tracks the last run only',
          after_tweaks == before + third.size, "#{before} -> #{after_tweaks}")

    Sketchup.undo
    after_undo = entities.length
    check('ONE undo removes every copy from the whole session',
          after_undo == before, "#{after_first}/#{after_tweaks} -> #{after_undo}, expected #{before}")
  end

  def place(path, settings, source, merge:)
    distances = BACommunity::PathCopyAdvanced::Distribution.distances(path, settings)
    transformations = BACommunity::PathCopyAdvanced::Placement.transformations(path, distances, settings, source)
    BACommunity::PathCopyAdvanced::Copier.run(model, [source], transformations, settings,
                                         merge_with_previous: merge)
  end

  # Drives the Tool itself as far as is possible without a mouse: real
  # Settings.load, real cursor creation, real selection adoption, real preview.
  def scenario_tool_activates
    edges = [
      entities.add_line(at(0, 2800), at(200, 2800)),
      entities.add_line(at(200, 2800), at(200, 3000)),
      entities.add_line(at(200, 3000), at(500, 3000))
    ]
    source = entities.add_instance(marker_definition('PCA_Marker'), Geom::Transformation.new(at(-200, 2800)))

    model.selection.clear
    model.selection.add(edges)

    tool = BACommunity::PathCopyAdvanced::Tool.new
    model.select_tool(tool)

    paths = tool.instance_variable_get(:@paths)
    check('tool adopted the pre-selection as a path', paths && paths.size == 1, paths&.size)
    check('tool moved to the source-picking stage',
          tool.instance_variable_get(:@state) == :source,
          tool.instance_variable_get(:@state).inspect)

    preview = tool.instance_variable_get(:@preview)
    check('preview was built from the selection', preview && preview.size == 1)
    check('preview has sample points', preview && preview.first[:points].size > 1,
          preview&.first&.dig(:points)&.size)

    # Simulate the object pick so the preview also builds transformations.
    tool.instance_variable_set(:@sources, [source])
    tool.send(:refresh)
    preview = tool.instance_variable_get(:@preview)
    check('preview builds transformations once a source is known',
          preview.first[:transformations].size == preview.first[:points].size,
          preview.first[:transformations].size)

    extents = tool.getExtents
    check('getExtents covers the path', !extents.empty?)

    cursor = tool.instance_variable_get(:@cursor)
    check('custom cursor was created from the icons folder', cursor.is_a?(Integer) && cursor != 0, cursor)

    $pca_tool = tool
    $pca_tool_source = source
  end

  # --- reporting -------------------------------------------------------

  def write_report
    passed = REPORT.count { |row| row[0] == 'PASS' }
    failed = REPORT.count { |row| row[0] == 'FAIL' }
    lines = REPORT.map { |status, name, detail| "#{status}  #{name}#{detail.empty? ? '' : "  [#{detail}]"}" }
    lines << ''
    lines << "#{REPORT.size} checks, #{passed} passed, #{failed} failed"

    path = File.expand_path('../build/live_test_result.txt', __dir__)
    File.write(path, lines.join("\n"))
    "#{REPORT.size} checks, #{passed} passed, #{failed} failed"
  end
end

begin
  PCALive.run
rescue Exception => error
  File.write(File.expand_path('../build/live_test_result.txt', __dir__),
             ["CRASH: #{error.class}: #{error.message}", *error.backtrace.first(15)].join("\n"))
  "CRASH: #{error.class}: #{error.message}"
end
