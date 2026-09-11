# frozen_string_literal: true
#
# Real mouse picking. Every earlier live check bypassed onLButtonDown; this one
# projects world points to screen pixels with view.screen_coords and sends the
# clicks through the tool, so the actual PickHelper does the picking.

module PCAPick
  REPORT = []
  BASE = Geom::Point3d.new(8000, 0, 0)
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

  def click(tool, view, world_point, flags = 0)
    screen = view.screen_coords(world_point)
    tool.onLButtonDown(flags, screen.x.round, screen.y.round, view)
    [screen.x.round, screen.y.round]
  end

  def run
    REPORT.clear
    view = model.active_view

    # An L of two plain edges plus three benches at different scales.
    edge_a = entities.add_line(at(0, 0), at(400, 0))
    edge_b = entities.add_line(at(400, 0), at(400, 300))
    bench_a = entities.add_instance(bench, Geom::Transformation.new(at(-200, 0)))
    bench_b = entities.add_instance(bench, Geom::Transformation.new(at(-200, 200)) * Geom::Transformation.scaling(2.0))
    bench_c = entities.add_instance(bench, Geom::Transformation.new(at(-200, -200)) * Geom::Transformation.scaling(0.5))

    # Straight down, framed tight so every pick target is well inside the viewport.
    camera = Sketchup::Camera.new(at(100, 50, 3000), at(100, 50, 0), Y_AXIS)
    camera.perspective = false
    view.camera = camera
    view.zoom([edge_a, edge_b, bench_a, bench_b, bench_c])
    view.refresh

    settings = BACommunity::PathCopyAdvanced::Settings.new
    settings.distribution = :count
    settings.count = 6
    settings.orientation = :flat
    settings.anchor = :bottom

    model.selection.clear
    tool = BACommunity::PathCopyAdvanced::Tool.new(settings)
    model.select_tool(tool)
    check('fresh tool starts at the path stage', tool.instance_variable_get(:@state) == :path)

    # 1. Click empty space first - nothing should happen.
    click(tool, view, at(250, -350))
    check('clicking empty space leaves the tool at the path stage',
          tool.instance_variable_get(:@state) == :path)

    # 2. Click the middle of the first edge.
    pixel = click(tool, view, at(200, 0))
    paths = tool.instance_variable_get(:@paths)
    check('clicking an edge picked it through the real PickHelper',
          tool.instance_variable_get(:@state) == :source, "state=#{tool.instance_variable_get(:@state)} px=#{pixel.inspect}")
    check('the picked edge grew into the whole L', paths.size == 1 && paths.first.points.size == 3,
          paths.map { |p| p.points.size }.inspect)
    check('the grown path has the right length',
          paths.first && (paths.first.length - 700.0).abs < 1.0e-3, paths.first&.length)

    # 3. Ctrl+click the 2x bench to queue it.
    click(tool, view, bench_b.bounds.center, COPY_MODIFIER_MASK)
    sources = tool.instance_variable_get(:@sources)
    check('Ctrl+click queued the object without placing',
          sources == [bench_b] && tool.instance_variable_get(:@state) == :source,
          "queued=#{sources.size} state=#{tool.instance_variable_get(:@state)}")

    # 4. Plain click the 1x bench - must add to the queue and place, not replace.
    click(tool, view, bench_a.bounds.center)
    sources = tool.instance_variable_get(:@sources)
    created = tool.instance_variable_get(:@created)
    check('plain click after Ctrl+click kept both objects',
          sources == [bench_b, bench_a], sources.size)
    check('the click placed the copies', tool.instance_variable_get(:@state) == :placed && created.size == 6,
          "state=#{tool.instance_variable_get(:@state)} created=#{created.size}")
    scales = created.map { |e| e.transformation.xscale.round(3) }
    check('copies alternate between the two picked objects',
          scales == [2.0, 1.0, 2.0, 1.0, 2.0, 1.0], scales.inspect)

    # 5. Ctrl+click a third object while placed - joins the rotation.
    click(tool, view, bench_c.bounds.center, COPY_MODIFIER_MASK)
    created = tool.instance_variable_get(:@created)
    scales = created.map { |e| e.transformation.xscale.round(3) }
    check('Ctrl+click while placed adds a third object to the rotation',
          scales == [2.0, 1.0, 0.5, 2.0, 1.0, 0.5], scales.inspect)

    # 6. Plain click one bench while placed - swaps to just that one.
    click(tool, view, bench_c.bounds.center)
    created = tool.instance_variable_get(:@created)
    scales = created.map { |e| e.transformation.xscale.round(3) }.uniq
    check('plain click while placed swaps to the clicked object only',
          scales == [0.5] && created.size == 6, scales.inspect)

    # 7. Clicking one of the freshly created copies must not pick it as a source.
    copy = created.first
    click(tool, view, copy.bounds.center)
    check('a created copy is refused as a source',
          tool.instance_variable_get(:@sources) == [bench_c],
          tool.instance_variable_get(:@sources).size)

    # 8. Escape twice: first removes the copies, second drops the path.
    before = entities.length
    tool.onCancel(0, view)
    check('first Esc removed the copies',
          tool.instance_variable_get(:@created).empty? && entities.length == before - 6,
          "#{before} -> #{entities.length}")
    tool.onCancel(0, view)
    check('second Esc dropped the path', tool.instance_variable_get(:@state) == :path)

    view.write_image(filename: "#{OUT}/pick_scene.png", width: 1200, height: 800, antialias: true)
    model.select_tool(nil)

    passed = REPORT.count { |r| r[0] == 'PASS' }
    lines = REPORT.map { |s, n, d| "#{s}  #{n}#{d.empty? ? '' : "  [#{d}]"}" }
    lines << ''
    lines << "#{REPORT.size} checks, #{passed} passed, #{REPORT.size - passed} failed"
    File.write("#{OUT}/live_pick_result.txt", lines.join("\n"))
    "#{REPORT.size} checks, #{passed} passed, #{REPORT.size - passed} failed"
  end
end

begin
  PCAPick.run
rescue Exception => error
  File.write(File.expand_path('../build/live_pick_result.txt', __dir__),
             ["CRASH: #{error.class}: #{error.message}", *error.backtrace.first(15)].join("\n"))
  "CRASH: #{error.class}: #{error.message}"
end
