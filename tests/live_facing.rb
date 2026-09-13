# frozen_string_literal: true
#
# Facing on closed loops and path reversal, against the real API. Two circles
# side by side - one told to face outward, one inward - rendered from above so
# the bench backs can be checked by eye as well as by dot product.

module PCAFacing
  REPORT = []
  BASE = Geom::Point3d.new(10_000, 0, 0)
  OUT = File.expand_path('../build', __dir__)

  module_function

  def model = Sketchup.active_model
  def entities = model.active_entities
  def at(dx, dy, dz = 0) = Geom::Point3d.new(BASE.x + dx, BASE.y + dy, BASE.z + dz)
  def check(name, condition, detail = '') = REPORT << [(condition ? 'PASS' : 'FAIL'), name, detail.to_s]

  def bench
    existing = model.definitions['PCA_Bench']
    return existing if existing

    definition = model.definitions.add('PCA_Bench')
    seat = definition.entities.add_face(
      Geom::Point3d.new(-30, -10, 0), Geom::Point3d.new(30, -10, 0),
      Geom::Point3d.new(30, 10, 0), Geom::Point3d.new(-30, 10, 0)
    )
    seat.pushpull(-4)
    back = definition.entities.add_face(
      Geom::Point3d.new(-30, 7, 4), Geom::Point3d.new(30, 7, 4),
      Geom::Point3d.new(30, 10, 4), Geom::Point3d.new(-30, 10, 4)
    )
    back.pushpull(-18)
    definition
  end

  def place(path, source, **overrides)
    settings = BACommunity::PathCopyAdvanced::Settings.new
    overrides.each { |key, value| settings.send("#{key}=", value) }
    distances = BACommunity::PathCopyAdvanced::Distribution.distances(path, settings)
    transformations = BACommunity::PathCopyAdvanced::Placement
                      .transformations(path, distances, settings, [source])
    BACommunity::PathCopyAdvanced::Copier.run(model, [source], transformations, settings)
  end

  # The bench back sits on local +Y, so "faces inward" means +Y points at the centre.
  def inward?(instance, centre)
    to_centre = centre - instance.transformation.origin
    instance.transformation.yaxis.dot(to_centre) > 0
  end

  def run
    REPORT.clear
    source = entities.add_instance(bench, Geom::Transformation.new(at(-500, 0)))

    # 1. Two identical circles (add_circle winds counter-clockwise about +Z).
    left_centre = at(0, 0)
    right_centre = at(900, 0)
    left = entities.add_circle(left_centre, Z_AXIS, 300, 48)
    right = entities.add_circle(right_centre, Z_AXIS, 300, 48)
    left_path = BACommunity::PathCopyAdvanced::PathBuilder.from_seed_edge(left.first)
    right_path = BACommunity::PathCopyAdvanced::PathBuilder.from_seed_edge(right.first)

    check('add_circle really winds counter-clockwise',
          BACommunity::PathCopyAdvanced::Placement.lateral_points_inward?(left_path) == true)

    outward = place(left_path, source, distribution: :count, count: 10, orientation: :flat,
                                       anchor: :bottom, facing: :outward)
    inward = place(right_path, source, distribution: :count, count: 10, orientation: :flat,
                                       anchor: :bottom, facing: :inward)

    check('outward: every bench back points away from the centre',
          outward.all? { |e| !inward?(e, left_centre) },
          outward.map { |e| inward?(e, left_centre) }.inspect)
    check('inward: every bench back points at the centre',
          inward.all? { |e| inward?(e, right_centre) },
          inward.map { |e| inward?(e, right_centre) }.inspect)
    check('both rings have the same ten positions relative to their centre',
          outward.zip(inward).all? do |a, b|
            (a.transformation.origin - left_centre).distance(b.transformation.origin - right_centre) < 1.0e-3
          end)

    # 2. A clockwise loop drawn by hand: auto now faces outward, inward flips it.
    cw = [at(0, 900), at(0, 1300), at(400, 1300), at(400, 900)]
    cw.each_cons(2) { |a, b| entities.add_line(a, b) }
    seed = entities.add_line(cw.last, cw.first)
    cw_path = BACommunity::PathCopyAdvanced::PathBuilder.from_seed_edge(seed)
    cw_centre = at(200, 1100)
    check('hand-drawn clockwise loop is detected as clockwise',
          cw_path.closed? && BACommunity::PathCopyAdvanced::Placement.lateral_points_inward?(cw_path) == false)
    auto = place(cw_path, source, distribution: :count, count: 8, orientation: :flat, anchor: :bottom, facing: :auto)
    fixed = place(cw_path, source, distribution: :count, count: 8, orientation: :flat, anchor: :bottom, facing: :inward)
    check('as drawn: clockwise loop faces outward', auto.all? { |e| !inward?(e, cw_centre) })
    check('face inward overrides the drawing direction', fixed.all? { |e| inward?(e, cw_centre) })
    BACommunity::PathCopyAdvanced::Copier.erase(model, auto, merge_with_previous: false)

    # 3. The keys, through the tool.
    view = model.active_view
    settings = BACommunity::PathCopyAdvanced::Settings.new
    settings.distribution = :count
    settings.count = 5
    settings.orientation = :flat
    model.selection.clear
    model.selection.add(entities.add_line(at(0, -800), at(600, -800)))
    tool = BACommunity::PathCopyAdvanced::Tool.new(settings)
    model.select_tool(tool)
    tool.instance_variable_set(:@sources, [source])
    tool.send(:commit)
    first_origin = tool.instance_variable_get(:@created).first.transformation.origin.clone

    tool.onKeyUp(82, 1, 0, view) # R
    check('R reverses the path direction', settings.reverse_path == true)
    reversed_origin = tool.instance_variable_get(:@created).first.transformation.origin
    check('after R the first copy sits at the other end of the path',
          (reversed_origin.x - at(600, -800).x).abs < 1.0e-3 && (first_origin.x - at(0, -800).x).abs < 1.0e-3,
          "#{first_origin.x.round(1)} -> #{reversed_origin.x.round(1)}")
    check('after R the copies point the other way',
          tool.instance_variable_get(:@created).first.transformation.xaxis.x < 0)

    tool.onKeyUp(70, 1, 0, view) # F
    check('F cycles the facing mode', settings.facing == :outward, settings.facing.inspect)
    check('the status summary names the new state',
          settings.summary.include?('Face outward') && settings.summary.include?('reversed'), settings.summary)

    tool.onCancel(0, view)
    tool.onCancel(0, view)
    model.select_tool(nil)

    # 4. Render the two rings from above.
    camera = Sketchup::Camera.new(at(450, 0, 3000), at(450, 0, 0), Y_AXIS)
    camera.perspective = false
    view.camera = camera
    view.zoom(left + right + outward + inward)
    view.write_image(filename: "#{OUT}/facing_rings.png", width: 1600, height: 800, antialias: true)

    passed = REPORT.count { |r| r[0] == 'PASS' }
    lines = REPORT.map { |s, n, d| "#{s}  #{n}#{d.empty? ? '' : "  [#{d}]"}" }
    lines << ''
    lines << "#{REPORT.size} checks, #{passed} passed, #{REPORT.size - passed} failed"
    File.write("#{OUT}/live_facing_result.txt", lines.join("\n"))
    lines.last
  end
end

begin
  PCAFacing.run
rescue Exception => error
  File.write(File.expand_path('../build/live_facing_result.txt', __dir__),
             ["CRASH: #{error.class}: #{error.message}", *error.backtrace.first(15)].join("\n"))
  "CRASH: #{error.class}: #{error.message}"
end
