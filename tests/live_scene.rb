# frozen_string_literal: true
#
# Clears the test geometry, builds a demo scene with the plugin, and renders it.
# The renders are the only way to see whether the copies actually sit and point
# the way the numbers claim.

module PCAScene
  BASE = Geom::Point3d.new(2000, 0, 0)
  OUT = File.expand_path('../build', __dir__)

  module_function

  def model = Sketchup.active_model
  def entities = model.active_entities
  def at(dx, dy, dz = 0) = Geom::Point3d.new(BASE.x + dx, BASE.y + dy, BASE.z + dz)

  def cleanup
    baseline = $pca_baseline || []
    doomed = entities.to_a - baseline
    doomed = doomed.select(&:valid?)
    model.start_operation('PCA cleanup', true)
    entities.erase_entities(doomed) unless doomed.empty?
    model.commit_operation
    doomed.size
  end

  # A bench: seat plus a back on the +Y side, so the heading of every copy is
  # unmistakable from above.
  def bench_definition
    model.definitions.remove(model.definitions['PCA_Bench']) if model.definitions['PCA_Bench']
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
                      .transformations(path, distances, settings, Array(source))
    BACommunity::PathCopyAdvanced::Copier.run(model, Array(source), transformations, settings)
  end

  def run
    removed = cleanup
    definition = bench_definition
    report = ["cleaned up #{removed} test entities"]

    # 1. An S-curve of PLAIN edges - no Curve, no Weld, the case the original
    #    could not do at all.
    points = (0..16).map do |i|
      t = i / 16.0
      at(t * 1200, Math.sin(t * Math::PI * 2) * 220)
    end
    seed = nil
    points.each_cons(2) do |a, b|
      edge = entities.add_line(a, b)
      seed ||= edge
    end
    check_curve = seed.curve.nil?
    s_path = BACommunity::PathCopyAdvanced::PathBuilder.from_seed_edge(seed)
    s_source = entities.add_instance(definition, Geom::Transformation.new(at(-200, 0)))
    s_copies = place(s_path, s_source, distribution: :spacing, spacing: 90.0,
                                       orientation: :flat, anchor: :bottom)
    report << "S-curve: seed edge has no Curve = #{check_curve}, " \
              "#{s_path.points.size} points, length #{s_path.length.round(1)}, " \
              "#{s_copies.size} copies"

    # 2. A circle, count mode, seam not duplicated.
    circle_edges = entities.add_circle(at(400, -900), Z_AXIS, 320, 48)
    circle_path = BACommunity::PathCopyAdvanced::PathBuilder.from_seed_edge(circle_edges.first)
    c_source = entities.add_instance(definition, Geom::Transformation.new(at(-200, -900)))
    c_copies = place(circle_path, c_source, distribution: :count, count: 12,
                                            orientation: :flat, anchor: :bottom, skip_seam: true)
    report << "circle: closed = #{circle_path.closed?}, #{c_copies.size} copies"

    # 3. A slope, full 3D orientation - the copies must tilt, not stay level.
    slope_edge = entities.add_line(at(0, -1600, 0), at(900, -1600, 450))
    slope_path = BACommunity::PathCopyAdvanced::PathBuilder.from_seed_edge(slope_edge)
    p_source = entities.add_instance(definition, Geom::Transformation.new(at(-200, -1600)))
    p_copies = place(slope_path, p_source, distribution: :count, count: 7,
                                           orientation: :tangent3d, anchor: :bottom)
    tilt = p_copies.first.transformation.xaxis
    report << "slope: #{p_copies.size} copies, first heading #{tilt.to_a.map { |v| v.round(3) }.inspect}"

    # 4. The same slope, flat orientation, for side-by-side comparison.
    flat_edge = entities.add_line(at(0, -2100, 0), at(900, -2100, 450))
    flat_path = BACommunity::PathCopyAdvanced::PathBuilder.from_seed_edge(flat_edge)
    f_source = entities.add_instance(definition, Geom::Transformation.new(at(-200, -2100)))
    f_copies = place(flat_path, f_source, distribution: :count, count: 7,
                                          orientation: :flat, anchor: :bottom)
    report << "slope flat: #{f_copies.size} copies, " \
              "first heading #{f_copies.first.transformation.xaxis.to_a.map { |v| v.round(3) }.inspect}"

    # 5. Randomised scatter along a straight run.
    jitter_edge = entities.add_line(at(0, -2600), at(1200, -2600))
    jitter_path = BACommunity::PathCopyAdvanced::PathBuilder.from_seed_edge(jitter_edge)
    j_source = entities.add_instance(definition, Geom::Transformation.new(at(-200, -2600)))
    j_copies = place(jitter_path, j_source, distribution: :spacing, spacing: 110.0,
                                            orientation: :flat, anchor: :bottom,
                                            jitter: true, jitter_angle: 25.0, jitter_scale: 0.3,
                                            jitter_lateral: 45.0, seed: 11)
    report << "jitter: #{j_copies.size} copies"

    [s_copies, c_copies, p_copies, f_copies, j_copies].flatten.compact
    render(report)
    report
  end

  def look(eye, target, up = Z_AXIS)
    model.active_view.camera = Sketchup::Camera.new(eye, target, up)
  end

  def shoot(name, width = 1600, height = 1000)
    model.active_view.write_image(
      filename: "#{OUT}/#{name}.png", width: width, height: height,
      antialias: true, transparent: false
    )
  end

  def render(report)
    view = model.active_view
    centre = at(500, -1200, 0)

    look(at(500, -1200, 4000), centre, Y_AXIS)
    view.zoom_extents
    view.zoom(entities.to_a.select { |e| e.bounds.center.x > BASE.x - 400 })
    shoot('scene_top')

    look(at(-1400, -4200, 2200), centre)
    view.zoom(entities.to_a.select { |e| e.bounds.center.x > BASE.x - 400 })
    shoot('scene_iso')

    look(at(2400, -1900, 200), at(2450, -1600, 200))
    view.zoom(entities.to_a.select { |e| e.bounds.center.y < BASE.y - 1400 && e.bounds.center.y > BASE.y - 2400 })
    shoot('scene_slopes')

    File.write("#{OUT}/live_scene_result.txt", report.join("\n"))
  end
end

begin
  PCAScene.run.join(' | ')
rescue Exception => error
  File.write(File.expand_path('../build/live_scene_result.txt', __dir__),
             ["CRASH: #{error.class}: #{error.message}", *error.backtrace.first(15)].join("\n"))
  "CRASH: #{error.class}: #{error.message}"
end
