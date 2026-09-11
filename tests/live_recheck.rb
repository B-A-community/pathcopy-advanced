# frozen_string_literal: true
#
# Follow-up to the two live failures: measure the actual geometry rather than
# reading a matrix field that does not mean what the assertion assumed.

module PCARecheck
  REPORT = []
  BASE = Geom::Point3d.new(4000, 0, 0)

  module_function

  def check(name, condition, detail = '')
    REPORT << [condition ? 'PASS' : 'FAIL', name, detail.to_s]
    condition
  end

  def close?(a, b, tolerance = 1.0e-3)
    (a.to_f - b.to_f).abs <= tolerance
  end

  def at(dx, dy, dz = 0)
    Geom::Point3d.new(BASE.x + dx, BASE.y + dy, BASE.z + dz)
  end

  def model = Sketchup.active_model
  def entities = model.active_entities

  def marker
    existing = model.definitions['PCA_Marker']
    return existing if existing

    definition = model.definitions.add('PCA_Marker')
    face = definition.entities.add_face(
      Geom::Point3d.new(0, -4, 0), Geom::Point3d.new(24, -4, 0),
      Geom::Point3d.new(24, 4, 0), Geom::Point3d.new(0, 4, 0)
    )
    face.pushpull(40)
    definition
  end

  def path_from(a, b)
    edge = entities.add_line(a, b)
    BACommunity::PathCopyAdvanced::PathBuilder.from_seed_edge(edge)
  end

  def place(path, source, **overrides)
    settings = BACommunity::PathCopyAdvanced::Settings.new
    overrides.each { |key, value| settings.send("#{key}=", value) }
    distances = BACommunity::PathCopyAdvanced::Distribution.distances(path, settings)
    transformations = BACommunity::PathCopyAdvanced::Placement
                      .transformations(path, distances, settings, Array(source))
    [BACommunity::PathCopyAdvanced::Copier.run(model, Array(source), transformations, settings),
     transformations, settings]
  end

  def run
    REPORT.clear
    check_scale
    check_group_anchor
    check_carry_over
    check_tag_and_group_result
    check_multi_source
    write_report
  end

  # --- 1. does a scaled component really come out scaled? --------------

  def check_scale
    source = entities.add_instance(marker, Geom::Transformation.new(at(-300, 0)))
    source.transformation = Geom::Transformation.new(at(-300, 0)) * Geom::Transformation.scaling(2.0)

    check('SketchUp keeps uniform scale outside the axis vectors',
          close?(source.transformation.xaxis.length, 1.0) &&
          close?(source.transformation.xscale, 2.0),
          "xaxis=#{source.transformation.xaxis.length.round(4)} xscale=#{source.transformation.xscale.round(4)}")

    path = path_from(at(0, 0), at(400, 0))
    created, = place(path, source, distribution: :count, count: 3, orientation: :flat)

    # The definition box is 24 long in X; at 2x a copy must measure 48.
    tip = Geom::Point3d.new(24, 0, 0)
    copy = created.first
    span = copy.transformation.origin.distance(tip.transform(copy.transformation))
    check('a 2x component copy really measures 2x', close?(span, 48.0, 1.0e-3), span.round(4))

    check('xscale survived the whole transform chain',
          created.all? { |e| close?(e.transformation.xscale, 2.0, 1.0e-3) },
          created.map { |e| e.transformation.xscale.round(4) }.inspect)

    # World bounds is the honest end-to-end measure: 48 x 16 x 80.
    bounds = copy.bounds
    check('world bounds of the copy are the doubled box',
          close?(bounds.width, 48.0, 1.0e-2) && close?(bounds.height, 16.0, 1.0e-2) &&
          close?(bounds.depth, 80.0, 1.0e-2),
          [bounds.width, bounds.height, bounds.depth].map { |v| v.round(3) }.inspect)

    source.erase! if source.valid?
  end

  # --- 2. where does a bottom-anchored group actually sit? -------------

  def check_group_anchor
    group = entities.add_group
    face = group.entities.add_face(at(0, 800), at(30, 800), at(30, 830), at(0, 830))
    face.pushpull(60)

    check('a group built this way has an identity transformation',
          close?(group.transformation.origin.x, 0) && close?(group.transformation.origin.y, 0),
          group.transformation.origin.to_a.inspect)

    path = path_from(at(0, 1000), at(300, 1000))
    created, = place(path, group, distribution: :count, count: 3,
                                  orientation: :flat, anchor: :bottom)

    copy = created.first
    bounds = copy.bounds
    centre_x = (bounds.min.x + bounds.max.x) / 2.0
    centre_y = (bounds.min.y + bounds.max.y) / 2.0
    target = at(0, 1000)

    check('bottom-anchored group sits centred on the path point',
          close?(centre_x, target.x, 1.0e-2) && close?(centre_y, target.y, 1.0e-2),
          "centre=(#{centre_x.round(3)}, #{centre_y.round(3)}) target=(#{target.x}, #{target.y})")
    check('bottom-anchored group rests at the path height',
          close?(bounds.min.z, target.z, 1.0e-2), bounds.min.z.round(3))
    check('group origin is deliberately NOT on the path when anchoring by bounds',
          !close?(copy.transformation.origin.y, target.y, 1.0),
          copy.transformation.origin.to_a.map { |v| v.round(2) }.inspect)

    # And with the default anchor the origin IS the thing that lands on it.
    path2 = path_from(at(0, 1200), at(300, 1200))
    created2, = place(path2, group, distribution: :count, count: 3,
                                    orientation: :flat, anchor: :origin)
    check('origin-anchored group puts its origin on the path',
          close?(created2.first.transformation.origin.y, at(0, 1200).y, 1.0e-2),
          created2.first.transformation.origin.to_a.map { |v| v.round(2) }.inspect)
  end

  # --- 3. material, tag, name, shadows --------------------------------

  def check_carry_over
    material = model.materials['PCA_Test'] || model.materials.add('PCA_Test')
    material.color = Sketchup::Color.new(200, 80, 40)
    layer = model.layers['PCA_SourceTag'] || model.layers.add('PCA_SourceTag')

    source = entities.add_instance(marker, Geom::Transformation.new(at(-300, 1600)))
    source.material = material
    source.layer = layer
    source.name = 'Bollard'

    path = path_from(at(0, 1600), at(300, 1600))
    created, = place(path, source, distribution: :count, count: 3, orientation: :flat)

    check('copies inherit the source material',
          created.all? { |e| e.material == material },
          created.map { |e| e.material&.name }.inspect)
    check('copies inherit the source tag',
          created.all? { |e| e.layer == layer }, created.map { |e| e.layer.name }.uniq.inspect)
    check('copies inherit the source name',
          created.all? { |e| e.name == 'Bollard' }, created.map(&:name).uniq.inspect)

    source.erase! if source.valid?
  end

  # --- 4. explicit tag + grouping the result --------------------------

  def check_tag_and_group_result
    source = entities.add_instance(marker, Geom::Transformation.new(at(-300, 2000)))
    path = path_from(at(0, 2000), at(300, 2000))

    created, = place(path, source, distribution: :count, count: 4,
                                   orientation: :flat, tag_name: 'PCA_Copies')
    check('the requested tag was created', !model.layers['PCA_Copies'].nil?)
    check('every copy got the requested tag',
          created.all? { |e| e.layer.name == 'PCA_Copies' },
          created.map { |e| e.layer.name }.uniq.inspect)

    path2 = path_from(at(0, 2200), at(300, 2200))
    grouped, = place(path2, source, distribution: :count, count: 4,
                                    orientation: :flat, group_result: true)
    check('grouping returns a single wrapper', grouped.size == 1, grouped.size)
    check('the wrapper is a Group', grouped.first.is_a?(Sketchup::Group), grouped.first.class.to_s)
    check('the wrapper holds all four copies',
          grouped.first.entities.length == 4, grouped.first.entities.length)
    check('the wrapper is named after the source',
          grouped.first.name.include?('PathCopy'), grouped.first.name)

    source.erase! if source.valid?
  end

  # --- 5. alternating two different objects ---------------------------

  def check_multi_source
    small = entities.add_instance(marker, Geom::Transformation.new(at(-300, 2600)))
    big = entities.add_instance(marker, Geom::Transformation.new(at(-400, 2600)))
    big.transformation = Geom::Transformation.new(at(-400, 2600)) * Geom::Transformation.scaling(3.0)

    path = path_from(at(0, 2600), at(600, 2600))
    created, = place(path, [small, big], distribution: :count, count: 6, orientation: :flat)

    scales = created.map { |e| e.transformation.xscale.round(3) }
    check('alternating sources keep their own scale', scales == [1.0, 3.0, 1.0, 3.0, 1.0, 3.0],
          scales.inspect)

    widths = created.map { |e| e.bounds.width.round(2) }
    check('the alternation is visible in real world size',
          widths[0] < widths[1] && close?(widths[1] / widths[0], 3.0, 0.05), widths.inspect)

    small.erase! if small.valid?
    big.erase! if big.valid?
  end

  def write_report
    passed = REPORT.count { |row| row[0] == 'PASS' }
    failed = REPORT.count { |row| row[0] == 'FAIL' }
    lines = REPORT.map { |s, n, d| "#{s}  #{n}#{d.empty? ? '' : "  [#{d}]"}" }
    lines << ''
    lines << "#{REPORT.size} checks, #{passed} passed, #{failed} failed"
    File.write(File.expand_path('../build/live_recheck_result.txt', __dir__), lines.join("\n"))
    "#{REPORT.size} checks, #{passed} passed, #{failed} failed"
  end
end

begin
  PCARecheck.run
rescue Exception => error
  File.write(File.expand_path('../build/live_recheck_result.txt', __dir__),
             ["CRASH: #{error.class}: #{error.message}", *error.backtrace.first(15)].join("\n"))
  "CRASH: #{error.class}: #{error.message}"
end
