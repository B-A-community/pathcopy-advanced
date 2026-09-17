# frozen_string_literal: true
#
# The railing scenario from the 2026-09-17 feedback: a rectangle drawn with the
# Rectangle tool (face + 4 edges), a stray line touching one corner, thin posts.
# Every vertex must get a post, corner posts must sit square to a rail, and a
# second run of railing must be addable with a modifier-click.

module PCAFence
  REPORT = []
  BASE = Geom::Point3d.new(14_000, 0, 0)
  OUT = File.expand_path('../build', __dir__)

  module_function

  def model = Sketchup.active_model
  def entities = model.active_entities
  def at(dx, dy, dz = 0) = Geom::Point3d.new(BASE.x + dx, BASE.y + dy, BASE.z + dz)
  def check(name, condition, detail = '') = REPORT << [(condition ? 'PASS' : 'FAIL'), name, detail.to_s]

  def post
    d = model.definitions['PCA_Post'] || model.definitions.add('PCA_Post')
    if d.entities.length.zero?
      f = d.entities.add_face(Geom::Point3d.new(-1, -5, 0), Geom::Point3d.new(1, -5, 0),
                              Geom::Point3d.new(1, 5, 0), Geom::Point3d.new(-1, 5, 0))
      f.pushpull(-100)
    end
    d
  end

  def heading(t)
    x = t.xaxis
    (Math.atan2(x.y, x.x) * 180 / Math::PI).round(1)
  end

  def near?(a, b, tol = 1.0e-3) = (a - b).abs < tol

  def click(tool, view, world_point, flags = 0)
    screen = view.screen_coords(world_point)
    tool.onLButtonDown(flags, screen.x.round, screen.y.round, view)
  end

  def run
    REPORT.clear
    ns = BACommunity::PathCopyAdvanced
    view = model.active_view

    face = entities.add_face(at(0, 0), at(400, 0), at(400, 300), at(0, 300))
    entities.add_line(at(400, 300), at(600, 500)) # stray line off a corner
    rect_edges = face.outer_loop.edges
    src = entities.add_instance(post, Geom::Transformation.new(at(-200, 0)))
    corners = [[0, 0], [400, 0], [400, 300], [0, 300]].map { |x, y| at(x, y) }

    # 1. Fit per segment at the tester's 345 mm: a post on every corner, and
    #    every post square to a rail - no 45 degree outlier anywhere.
    rect_edges.each_with_index do |seed, i|
      path = ns::PathBuilder.from_seed_edge(seed)
      s = ns::Settings.new
      s.distribution = :segments
      s.spacing = 345.mm
      s.orientation = :flat
      s.anchor = :bottom
      transformations = ns::Placement.transformations(path, ns::Distribution.distances(path, s), s, src)
      origins = transformations.map(&:origin)
      on_corners = corners.all? { |c| origins.any? { |o| near?(o.x, c.x, 1.0e-2) && near?(o.y, c.y, 1.0e-2) } }
      headings = transformations.map { |t| heading(t) }
      square = headings.all? { |h| [0.0, 90.0, 180.0, -90.0, -180.0].any? { |r| near?(h, r, 0.5) } }
      check("seed edge #{i}: a post on all four corners", on_corners, origins.size)
      check("seed edge #{i}: every post square to a rail", square, headings.uniq.inspect)
    end

    # 2. Same rectangle, vertices mode: the four corner posts each follow the
    #    rail leaving their corner.
    path = ns::PathBuilder.from_seed_edge(rect_edges.first)
    s = ns::Settings.new
    s.distribution = :vertices
    s.orientation = :flat
    headings = ns::Placement.transformations(path, ns::Distribution.distances(path, s), s, src).map { |t| heading(t) }
    check('vertices mode: corner posts follow the outgoing rail, none on a bisector',
          headings.none? { |h| near?(h.abs % 90, 45.0, 0.5) }, headings.inspect)

    # 3. Fit mode on the whole perimeter is unchanged apart from the corner fix.
    s.distribution = :fit
    s.spacing = 345.mm
    headings = ns::Placement.transformations(path, ns::Distribution.distances(path, s), s, src).map { |t| heading(t) }
    check('fit mode: the copy on the start vertex no longer stands at 45 degrees',
          headings.none? { |h| near?(h.abs % 90, 45.0, 0.5) }, headings.uniq.inspect)

    # 4. Two runs of railing in one go, through the mouse: click the first
    #    rectangle's edge, modifier-click a second polyline, click the post.
    run2 = [at(0, -600), at(300, -600), at(300, -400)]
    second_edges = run2.each_cons(2).map { |a, b| entities.add_line(a, b) }
    camera = Sketchup::Camera.new(at(300, -100, 4000), at(300, -100, 0), Y_AXIS)
    camera.perspective = false
    view.camera = camera
    view.zoom(rect_edges + second_edges + [src])
    view.refresh

    settings = ns::Settings.new
    settings.distribution = :segments
    settings.spacing = 100.0
    settings.orientation = :flat
    settings.anchor = :bottom
    model.selection.clear
    tool = ns::Tool.new(settings)
    model.select_tool(tool)

    click(tool, view, at(200, 0))                                  # rectangle bottom edge
    click(tool, view, at(150, -600), COPY_MODIFIER_MASK)           # modifier: add second run
    paths = tool.instance_variable_get(:@paths)
    check('modifier-click on an edge added a second path', paths.size == 2 && tool.instance_variable_get(:@state) == :source,
          "paths=#{paths.size} state=#{tool.instance_variable_get(:@state)}")
    click(tool, view, at(150, -600), COPY_MODIFIER_MASK)           # same edge again: no duplicate
    check('the same path is not added twice', tool.instance_variable_get(:@paths).size == 2)

    click(tool, view, src.bounds.center)                            # place
    created = tool.instance_variable_get(:@created)
    check('one click placed posts on both runs', tool.instance_variable_get(:@state) == :placed && created.size > 8, created.size)
    on_second = created.count { |e| e.transformation.origin.y < at(0, -300).y }
    check('the second run got its posts too', on_second == 6, on_second)

    click(tool, view, at(100, 300), COPY_MODIFIER_MASK)             # while placed: edge of the same rectangle -> already known
    check('modifier-click on a known path while placed changes nothing', tool.instance_variable_get(:@paths).size == 2)

    tool.onKeyDown(9, 1, 0, view)                                    # Tab cycles the mode
    check('Tab on key down cycles the mode', settings.distribution != :segments, settings.distribution.inspect)
    tool.onKeyDown(102, 1, 0, view)                                  # lower-case f, as macOS sends it
    check('lower-case f is accepted for facing', settings.facing == :outward, settings.facing.inspect)
    tool.onKeyDown(114, 1, 0, view)                                  # lower-case r
    check('lower-case r is accepted for reverse', settings.reverse_path == true)
    check('the hint names the platform modifier', ns::Tool::MODIFIER == (Sketchup.platform == :platform_osx ? 'Option' : 'Ctrl'))

    tool.onCancel(0, view)
    tool.onCancel(0, view)
    model.select_tool(nil)

    # 5. A picture for the tester: fit per segment at 345 mm on the rectangle.
    s = ns::Settings.new
    s.distribution = :segments
    s.spacing = 345.mm
    s.orientation = :flat
    s.anchor = :bottom
    path = ns::PathBuilder.from_seed_edge(rect_edges.first)
    ns::Copier.run(model, [src], ns::Placement.transformations(path, ns::Distribution.distances(path, s), s, src), s)
    look = Sketchup::Camera.new(at(-300, -700, 500), at(200, 150, 0), Z_AXIS)
    view.camera = look
    view.zoom(rect_edges)
    view.write_image(filename: "#{OUT}/fence_rectangle.png", width: 1400, height: 900, antialias: true)

    passed = REPORT.count { |r| r[0] == 'PASS' }
    lines = REPORT.map { |st, n, d| "#{st}  #{n}#{d.empty? ? '' : "  [#{d}]"}" }
    lines << ''
    lines << "#{REPORT.size} checks, #{passed} passed, #{REPORT.size - passed} failed"
    File.write("#{OUT}/live_fence_result.txt", lines.join("\n"))
    lines.last
  end
end

begin
  PCAFence.run
rescue Exception => error
  File.write(File.expand_path('../build/live_fence_result.txt', __dir__),
             ["CRASH: #{error.class}: #{error.message}", *error.backtrace.first(15)].join("\n"))
  "CRASH: #{error.class}: #{error.message}"
end
