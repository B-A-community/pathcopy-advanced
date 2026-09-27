# frozen_string_literal: true
#
# Поручень вдоль пути и доворот отдельных копий кликом (правки 2026-09-27).
# Проверяется на настоящей геометрии: солид ли получился, сходятся ли грани на
# углах, переживает ли ручной доворот перестройку копий.

module PCARailing
  REPORT = []
  BASE = Geom::Point3d.new(18_000, 0, 0)
  OUT = File.expand_path('../build', __dir__)

  module_function

  def ns = BACommunity::PathCopyAdvanced
  def model = Sketchup.active_model
  def entities = model.active_entities
  def at(dx, dy, dz = 0) = Geom::Point3d.new(BASE.x + dx, BASE.y + dy, BASE.z + dz)
  def check(name, condition, detail = '') = REPORT << [(condition ? 'PASS' : 'FAIL'), name, detail.to_s]
  def near?(a, b, tol = 1.0e-3) = (a - b).abs < tol

  def post
    d = model.definitions['PCA_Post'] || model.definitions.add('PCA_Post')
    if d.entities.length.zero?
      f = d.entities.add_face(Geom::Point3d.new(-1, -5, 0), Geom::Point3d.new(1, -5, 0),
                              Geom::Point3d.new(1, 5, 0), Geom::Point3d.new(-1, 5, 0))
      f.pushpull(-100)
    end
    d
  end

  def settings(**overrides)
    s = ns::Settings.new
    overrides.each { |k, v| s.send("#{k}=", v) }
    s.sanitize!
    s
  end

  def heading(t)
    (Math.atan2(t.xaxis.y, t.xaxis.x) * 180 / Math::PI).round(1)
  end

  def click(tool, view, point, flags = 0)
    screen = view.screen_coords(point)
    tool.onLButtonDown(flags, screen.x.round, screen.y.round, view)
  end

  def run
    REPORT.clear
    view = model.active_view

    # --- 1. Прямоугольный профиль на ломаном пути ------------------------
    pts = [at(0, 0), at(600, 0), at(600, 500)]
    edges = pts.each_cons(2).map { |a, b| entities.add_line(a, b) }
    path = ns::PathBuilder.from_seed_edge(edges.first)
    s = settings(rail: true, rail_width: 50.mm, rail_height: 50.mm, rail_shape: :rect, rail_align: :center)

    rings = ns::Railing.sections(path, s)
    check('одно сечение на каждую вершину пути', rings.size == 3, rings.size)
    check('в прямоугольном сечении четыре точки', rings.all? { |r| r.size == 4 }, rings.map(&:size).inspect)

    # Митра: сечение в углу лежит в плоскости-биссектрисе, то есть его точки
    # равноудалены от обеих соседних осей — проверяем по нормали.
    corner = rings[1]
    d_in = (pts[1] - pts[0]).normalize
    d_out = (pts[2] - pts[1]).normalize
    bis = Geom::Vector3d.new(d_in.x + d_out.x, d_in.y + d_out.y, d_in.z + d_out.z).normalize
    flat = corner.all? { |p| near?((p - pts[1]).dot(bis), 0.0, 1.0e-6) }
    check('угловое сечение лежит в плоскости среза', flat,
          corner.map { |p| (p - pts[1]).dot(bis).round(6) }.inspect)

    rail = ns::Railing.build(entities, path, s)
    check('поручень построен группой', rail.is_a?(Sketchup::Group))
    faces = rail.entities.grep(Sketchup::Face).size
    check('граней столько, сколько нужно на два участка с торцами', faces == 10, faces)
    check('получился солид — значит грани сошлись без щелей', rail.manifold?, rail.manifold?)
    bounds = rail.bounds
    check('высота профиля совпадает с заданной', near?(bounds.depth, 50.mm, 1.0e-3), bounds.depth)
    rail.erase!

    # --- 2. Круглое сечение ----------------------------------------------
    round = ns::Railing.build(entities, path, settings(rail: true, rail_shape: :round,
                                                       rail_width: 40.mm, rail_height: 40.mm))
    check('круглый профиль тоже солид', round.manifold?)
    check('круглый профиль гранёный по числу сегментов',
          round.entities.grep(Sketchup::Face).size == ns::Railing::ROUND_SEGMENTS * 2 + 2,
          round.entities.grep(Sketchup::Face).size)
    check('продольные рёбра круглого профиля сглажены',
          round.entities.grep(Sketchup::Edge).count(&:soft?) > ns::Railing::ROUND_SEGMENTS,
          round.entities.grep(Sketchup::Edge).count(&:soft?))
    round.erase!

    # --- 3. Привязка и продление концов ----------------------------------
    # На ломаном пути у участков разные боковые оси, и центр габаритов уезжает
    # по диагонали - привязку меряем на прямом отрезке, где сдвиг равен ширине.
    straight_edge = entities.add_line(at(0, -900), at(600, -900))
    straight = ns::PathBuilder.from_seed_edge(straight_edge)
    centre = ns::Railing.build(entities, straight, settings(rail: true, rail_align: :center, rail_width: 100.mm))
    outward = ns::Railing.build(entities, straight, settings(rail: true, rail_align: :outward, rail_width: 100.mm))
    inward = ns::Railing.build(entities, straight, settings(rail: true, rail_align: :inward, rail_width: 100.mm))

    check('наружу и внутрь расходятся ровно на ширину профиля',
          near?(outward.bounds.center.distance(inward.bounds.center), 100.mm, 1.0e-2),
          outward.bounds.center.distance(inward.bounds.center))
    check('по центру профиль сидит на самой линии',
          near?(centre.bounds.center.y, at(0, -900).y, 1.0e-2), centre.bounds.center.y)
    check('наружу — профиль целиком с одной стороны линии',
          near?(outward.bounds.min.y, at(0, -900).y, 1.0e-2), outward.bounds.min.y)
    check('внутрь — целиком с другой',
          near?(inward.bounds.max.y, at(0, -900).y, 1.0e-2), inward.bounds.max.y)
    [centre, outward, inward].each(&:erase!)

    plain = ns::Railing.build(entities, path, settings(rail: true, rail_extend: 0))
    longer = ns::Railing.build(entities, path, settings(rail: true, rail_extend: 200.mm))
    check('продление концов удлиняет поручень на оба конца',
          near?(longer.bounds.width - plain.bounds.width, 200.mm, 1.0e-2),
          [plain.bounds.width, longer.bounds.width].map { |v| v.round(2) }.inspect)
    [plain, longer].each(&:erase!)

    # --- 4. Замкнутый контур: без торцов, кольцо целиком -----------------
    circle = entities.add_circle(at(1500, 0), Z_AXIS, 300, 24)
    loop_path = ns::PathBuilder.from_seed_edge(circle.first)
    ring = ns::Railing.build(entities, loop_path, settings(rail: true, rail_width: 60.mm, rail_height: 60.mm))
    check('на замкнутом контуре поручень замкнут и без торцов',
          ring.manifold? && ring.entities.grep(Sketchup::Face).size == 24 * 4,
          ring.entities.grep(Sketchup::Face).size)
    ring.erase!

    # --- 5. Поручень и стойки одной операцией ----------------------------
    src = entities.add_instance(post, Geom::Transformation.new(at(-300, 0)))
    s = settings(rail: true, rail_width: 50.mm, rail_height: 50.mm, distribution: :segments,
                 spacing: 150.mm, orientation: :flat, anchor: :bottom)
    model.selection.clear
    model.selection.add(edges)
    tool = ns::Tool.new(s)
    model.select_tool(tool)
    tool.instance_variable_set(:@sources, [src])
    tool.send(:commit)
    created = tool.instance_variable_get(:@created)
    posts = created.count { |e| e.is_a?(Sketchup::ComponentInstance) }
    rails = created.count { |e| e.is_a?(Sketchup::Group) }
    check('за один клик встали и стойки, и поручень', posts > 5 && rails == 1, "#{posts} / #{rails}")

    before = entities.length
    Sketchup.undo
    check('один Undo снял и стойки, и поручень', entities.length < before, "#{before} -> #{entities.length}")

    # --- 6. Доворот отдельной копии кликом --------------------------------
    tool2 = ns::Tool.new(settings(distribution: :count, count: 5, orientation: :flat, anchor: :bottom))
    model.selection.clear
    model.selection.add(edges.select(&:valid?))
    model.select_tool(tool2)
    tool2.instance_variable_set(:@sources, [src])
    tool2.send(:commit)
    copies = tool2.instance_variable_get(:@created)
    check('пять копий для доворота', copies.size == 5, copies.size)

    camera = Sketchup::Camera.new(at(300, 250, 4000), at(300, 250, 0), Y_AXIS)
    camera.perspective = false
    view.camera = camera
    view.zoom(copies)
    view.refresh

    # Перестройка пересоздаёт копии, поэтому запоминаем ЗНАЧЕНИЯ, а не ссылки:
    # старые сущности к моменту проверки уже удалены.
    before_headings = copies.map { |c| heading(c.transformation) }
    before_origin = copies[2].transformation.origin.clone
    target_point = copies[2].bounds.center

    click(tool2, view, target_point)
    after = tool2.instance_variable_get(:@created)
    check('клик по копии довернул именно её',
          near?((heading(after[2].transformation) - before_headings[2]) % 360, 90.0, 0.5),
          "#{before_headings[2]} -> #{heading(after[2].transformation)}")
    check('соседние копии не тронуты',
          near?(heading(after[1].transformation), before_headings[1], 0.5) &&
          near?(heading(after[3].transformation), before_headings[3], 0.5),
          [heading(after[1].transformation), heading(after[3].transformation)].inspect)
    check('копия не сдвинулась с места',
          after[2].transformation.origin.distance(before_origin) < 1.0e-3,
          after[2].transformation.origin.distance(before_origin))

    click(tool2, view, after[2].bounds.center)
    after = tool2.instance_variable_get(:@created)
    check('второй клик доворачивает ещё на столько же',
          near?((heading(after[2].transformation) - before_headings[2]) % 360, 180.0, 0.5),
          heading(after[2].transformation))

    shift = defined?(CONSTRAIN_MODIFIER_MASK) ? CONSTRAIN_MODIFIER_MASK : 4
    click(tool2, view, after[2].bounds.center, shift)
    after = tool2.instance_variable_get(:@created)
    check('Shift+клик доворачивает обратно',
          near?((heading(after[2].transformation) - before_headings[2]) % 360, 90.0, 0.5),
          heading(after[2].transformation))

    # Перестройка копий не должна потерять ручной доворот.
    tool2.instance_variable_get(:@settings).count = 5
    tool2.settings_changed
    after = tool2.instance_variable_get(:@created)
    check('доворот пережил перестройку копий',
          near?((heading(after[2].transformation) - before_headings[2]) % 360, 90.0, 0.5),
          heading(after[2].transformation))
    check('панель знает, сколько копий довёрнуто вручную',
          tool2.panel_context[:nudged] == 1, tool2.panel_context.inspect)

    tool2.clear_nudges
    tool2.settings_changed
    after = tool2.instance_variable_get(:@created)
    check('сброс возвращает общую ориентацию',
          near?(heading(after[2].transformation), before_headings[2], 0.5), heading(after[2].transformation))

    tool2.onCancel(0, view)
    tool2.onCancel(0, view)
    model.select_tool(nil)

    # --- 7. Картинка -------------------------------------------------------
    s = settings(rail: true, rail_width: 60.mm, rail_height: 40.mm, rail_extend: 100.mm,
                 distribution: :segments, spacing: 150.mm, orientation: :flat, anchor: :bottom)
    tf = ns::Placement.transformations(path, ns::Distribution.distances(path, s), s, src)
    shot = ns::Copier.run(model, [src], tf, s, paths: [path])
    look = Sketchup::Camera.new(at(-500, -700, 500), at(300, 250, 50), Z_AXIS)
    look.perspective = true
    view.camera = look
    view.zoom(shot)
    view.write_image(filename: "#{OUT}/railing.png", width: 1500, height: 900, antialias: true)

    passed = REPORT.count { |r| r[0] == 'PASS' }
    lines = REPORT.map { |st, n, d| "#{st}  #{n}#{d.empty? ? '' : "  [#{d}]"}" }
    lines << ''
    lines << "#{REPORT.size} checks, #{passed} passed, #{REPORT.size - passed} failed"
    File.write("#{OUT}/live_railing_result.txt", lines.join("\n"))
    lines.last
  end
end

begin
  PCARailing.run
rescue Exception => error
  File.write(File.expand_path('../build/live_railing_result.txt', __dir__),
             ["CRASH: #{error.class}: #{error.message}", *error.backtrace.first(15)].join("\n"))
  "CRASH: #{error.class}: #{error.message}"
end
