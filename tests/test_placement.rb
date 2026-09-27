# frozen_string_literal: true

def place(path, settings, source)
  Placement.transformations(path, Distribution.distances(path, settings), settings, source)
end

test 'copies land exactly on the sampled points' do
  path = build_path([[0, 0, 0], [100, 0, 0]])
  settings = settings_with(distribution: :spacing, spacing: 50.0)
  transformations = place(path, settings, instance_with)

  assert_equal 3, transformations.size
  assert_point [0, 0, 0], transformations[0].origin
  assert_point [50, 0, 0], transformations[1].origin
  assert_point [100, 0, 0], transformations[2].origin
end

test 'the source scale survives, which it did not in the original' do
  source = instance_with(transformation: Geom::Transformation.scaling(2.0))
  path = build_path([[0, 0, 0], [100, 0, 0]])
  transformations = place(path, settings_with(distribution: :count, count: 2), source)

  assert_close 2.0, transformations.first.xaxis.length
  assert_close 2.0, transformations.first.zaxis.length
end

test 'the source rotation survives too' do
  spin = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees)
  source = instance_with(transformation: spin)
  path = build_path([[0, 0, 0], [100, 0, 0]])
  transformations = place(path, settings_with(distribution: :count, count: 1, orientation: :none), source)

  assert_vector [0, 1, 0], transformations.first.xaxis
end

test 'flat orientation turns the object to follow the path heading' do
  path = build_path([[0, 0, 0], [0, 100, 0]])
  transformations = place(path, settings_with(distribution: :count, count: 1, orientation: :flat), instance_with)

  assert_vector [0, 1, 0], transformations.first.xaxis
  assert_vector [0, 0, 1], transformations.first.zaxis
end

test 'keep-orientation mode leaves the axes alone' do
  path = build_path([[0, 0, 0], [0, 100, 0]])
  transformations = place(path, settings_with(distribution: :count, count: 1, orientation: :none), instance_with)

  assert_vector [1, 0, 0], transformations.first.xaxis
end

test '3D orientation tilts with the slope' do
  path = build_path([[0, 0, 0], [100, 0, 100]])
  transformations = place(path, settings_with(distribution: :count, count: 1, orientation: :tangent3d), instance_with)

  root = Math.sqrt(0.5)
  assert_vector [root, 0, root], transformations.first.xaxis
end

test 'a vertical segment holds the previous heading instead of collapsing' do
  # flat_angle in the original returned an arbitrary 180 degrees here.
  path = build_path([[0, 0, 0], [100, 0, 0], [100, 0, 100]])
  settings = settings_with(distribution: :spacing, spacing: 50.0, orientation: :flat)
  transformations = place(path, settings, instance_with)

  assert_equal 5, transformations.size
  assert_point [100, 0, 50], transformations[3].origin
  assert_vector [1, 0, 0], transformations[3].xaxis
  assert_vector [1, 0, 0], transformations[4].xaxis
end

test 'a purely vertical path does not raise' do
  path = build_path([[0, 0, 0], [0, 0, 100]])
  transformations = place(path, settings_with(distribution: :count, count: 3, orientation: :flat), instance_with)
  assert_equal 3, transformations.size
  assert_point [0, 0, 50], transformations[1].origin
end

test 'the bounds-center anchor puts the object centre on the path' do
  source = instance_with(bounds: [[0, 0, 0], [10, 4, 6]])
  path = build_path([[0, 0, 0], [100, 0, 0]])
  settings = settings_with(distribution: :count, count: 1, anchor: :center, orientation: :none)
  transformation = place(path, settings, source).first

  centre = source.definition.bounds.center
  assert_point [50, 0, 0], centre.transform(transformation)
end

test 'the bottom anchor sits the object on the path' do
  source = instance_with(bounds: [[0, 0, 0], [10, 4, 6]])
  path = build_path([[0, 0, 0], [100, 0, 0]])
  settings = settings_with(distribution: :count, count: 1, anchor: :bottom, orientation: :none)
  transformation = place(path, settings, source).first

  bounds = source.definition.bounds
  bottom = Geom::Point3d.new(bounds.center.x, bounds.center.y, bounds.min.z)
  assert_point [50, 0, 0], bottom.transform(transformation)
end

test 'sideways and vertical offsets are measured in the path frame' do
  path = build_path([[0, 0, 0], [0, 100, 0]])
  settings = settings_with(distribution: :count, count: 1, orientation: :flat,
                           offset_lateral: 10.0, offset_vertical: 5.0)
  transformation = place(path, settings, instance_with).first

  # Path runs along +Y, so its local +Y (sideways) points at world -X.
  assert_point [-10, 50, 5], transformation.origin
end

test 'flipping every second copy turns it around' do
  path = build_path([[0, 0, 0], [100, 0, 0]])
  settings = settings_with(distribution: :count, count: 2, orientation: :flat, alternate_flip: true)
  transformations = place(path, settings, instance_with)

  assert_vector [1, 0, 0], transformations[0].xaxis
  assert_vector [-1, 0, 0], transformations[1].xaxis
end

test 'randomisation is reproducible for a given seed' do
  path = build_path([[0, 0, 0], [1000, 0, 0]])
  options = { distribution: :count, count: 20, jitter: true, jitter_lateral: 12.0,
              jitter_angle: 30.0, jitter_scale: 0.25, seed: 42 }

  first = place(path, settings_with(**options), instance_with).map { |t| t.origin.to_a }
  second = place(path, settings_with(**options), instance_with).map { |t| t.origin.to_a }
  third = place(path, settings_with(**options.merge(seed: 43)), instance_with).map { |t| t.origin.to_a }

  assert_equal first, second
  assert first != third, 'a different seed should give a different layout'
end

test 'randomisation stays inside the requested bounds' do
  path = build_path([[0, 0, 0], [1000, 0, 0]])
  settings = settings_with(distribution: :count, count: 50, orientation: :flat,
                           jitter: true, jitter_lateral: 10.0, seed: 7)
  transformations = place(path, settings, instance_with)

  transformations.each do |transformation|
    assert transformation.origin.y.abs <= 10.0 + 1.0e-9,
           "lateral jitter escaped its bound: #{transformation.origin.y}"
  end
end

test 'scale jitter never inverts or collapses an object' do
  path = build_path([[0, 0, 0], [1000, 0, 0]])
  settings = settings_with(distribution: :count, count: 100, jitter: true, jitter_scale: 0.9, seed: 3)
  place(path, settings, instance_with).each do |transformation|
    assert transformation.xaxis.length > 0.0, 'scale collapsed to zero'
  end
end

test 'alternating sources each keep their own scale' do
  plain = instance_with
  big = instance_with(transformation: Geom::Transformation.scaling(2.0))
  path = build_path([[0, 0, 0], [300, 0, 0]])
  settings = settings_with(distribution: :count, count: 4, orientation: :none)

  transformations = Placement.transformations(
    path, Distribution.distances(path, settings), settings, [plain, big]
  )

  assert_close 1.0, transformations[0].xaxis.length
  assert_close 2.0, transformations[1].xaxis.length
  assert_close 1.0, transformations[2].xaxis.length
  assert_close 2.0, transformations[3].xaxis.length
end

test 'the index offset keeps alternation continuous across several paths' do
  path = build_path([[0, 0, 0], [100, 0, 0]])
  settings = settings_with(distribution: :count, count: 2, orientation: :flat, alternate_flip: true)
  distances = Distribution.distances(path, settings)

  first_path = Placement.transformations(path, distances, settings, instance_with, index_offset: 0)
  second_path = Placement.transformations(path, distances, settings, instance_with, index_offset: 2)

  assert_vector [1, 0, 0], first_path[0].xaxis
  assert_vector [-1, 0, 0], first_path[1].xaxis
  # Copy 2 and 3 overall, so the flip pattern carries on rather than restarting.
  assert_vector [1, 0, 0], second_path[0].xaxis
  assert_vector [-1, 0, 0], second_path[1].xaxis
end

test 'an empty source list yields nothing rather than raising' do
  path = build_path([[0, 0, 0], [100, 0, 0]])
  settings = settings_with(distribution: :count, count: 3)
  assert_equal [], Placement.transformations(path, Distribution.distances(path, settings), settings, [])
end

# --- facing on closed loops ----------------------------------------------------

CCW_SQUARE = [[0, 0, 0], [100, 0, 0], [100, 100, 0], [0, 100, 0], [0, 0, 0]].freeze
CW_SQUARE  = CCW_SQUARE.reverse.freeze

def lateral_towards_centre?(transformation, centre)
  to_centre = centre - transformation.origin
  transformation.yaxis.dot(to_centre) > 0
end

test 'on a counter-clockwise loop the left-hand side already faces inward' do
  path = build_path(CCW_SQUARE, closed: true)
  settings = settings_with(distribution: :count, count: 4, orientation: :flat, facing: :auto)
  centre = Geom::Point3d.new(50, 50, 0)
  place(path, settings, instance_with).each do |t|
    assert lateral_towards_centre?(t, centre), "expected +Y towards centre at #{t.origin}"
  end
end

test 'on a clockwise loop the left-hand side faces outward by default' do
  path = build_path(CW_SQUARE, closed: true)
  settings = settings_with(distribution: :count, count: 4, orientation: :flat, facing: :auto)
  centre = Geom::Point3d.new(50, 50, 0)
  place(path, settings, instance_with).each do |t|
    assert !lateral_towards_centre?(t, centre), "expected +Y away from centre at #{t.origin}"
  end
end

test 'requesting inward on a clockwise loop turns every copy around' do
  path = build_path(CW_SQUARE, closed: true)
  centre = Geom::Point3d.new(50, 50, 0)
  settings = settings_with(distribution: :count, count: 4, orientation: :flat, facing: :inward)
  place(path, settings, instance_with).each do |t|
    assert lateral_towards_centre?(t, centre), "expected +Y towards centre at #{t.origin}"
  end
end

test 'requesting outward on a counter-clockwise loop turns every copy around' do
  path = build_path(CCW_SQUARE, closed: true)
  centre = Geom::Point3d.new(50, 50, 0)
  settings = settings_with(distribution: :count, count: 4, orientation: :flat, facing: :outward)
  place(path, settings, instance_with).each do |t|
    assert !lateral_towards_centre?(t, centre), "expected +Y away from centre at #{t.origin}"
  end
end

test 'facing is honoured with 3D orientation too' do
  path = build_path(CCW_SQUARE, closed: true)
  centre = Geom::Point3d.new(50, 50, 0)
  settings = settings_with(distribution: :count, count: 4, orientation: :tangent3d, facing: :outward)
  place(path, settings, instance_with).each do |t|
    assert !lateral_towards_centre?(t, centre)
  end
end

test 'the turn-around does not touch the copy positions' do
  path = build_path(CCW_SQUARE, closed: true)
  a = place(path, settings_with(distribution: :count, count: 4, orientation: :flat, facing: :auto), instance_with)
  b = place(path, settings_with(distribution: :count, count: 4, orientation: :flat, facing: :outward), instance_with)
  a.zip(b).each { |x, y| assert_point x.origin.to_a, y.origin }
  assert_vector (a.first.xaxis.to_a.map { |v| -v }), b.first.xaxis
end

test 'facing has no effect on an open path' do
  path = build_path([[0, 0, 0], [100, 0, 0], [100, 100, 0]])
  a = place(path, settings_with(distribution: :count, count: 3, orientation: :flat, facing: :auto), instance_with)
  b = place(path, settings_with(distribution: :count, count: 3, orientation: :flat, facing: :inward), instance_with)
  a.zip(b).each { |x, y| assert_vector x.xaxis.to_a, y.xaxis }
end

test 'facing has no effect when orientation is kept' do
  path = build_path(CW_SQUARE, closed: true)
  a = place(path, settings_with(distribution: :count, count: 4, orientation: :none, facing: :auto), instance_with)
  b = place(path, settings_with(distribution: :count, count: 4, orientation: :none, facing: :inward), instance_with)
  a.zip(b).each { |x, y| assert_vector x.xaxis.to_a, y.xaxis }
end

test 'a vertical loop has no inside in plan and is left alone' do
  wall = [[0, 0, 0], [100, 0, 0], [100, 0, 100], [0, 0, 100], [0, 0, 0]]
  path = build_path(wall, closed: true)
  a = place(path, settings_with(distribution: :count, count: 4, orientation: :flat, facing: :auto), instance_with)
  b = place(path, settings_with(distribution: :count, count: 4, orientation: :flat, facing: :inward), instance_with)
  a.zip(b).each { |x, y| assert_vector x.xaxis.to_a, y.xaxis }
end

test 'a concave loop still gets a consistent winding' do
  # An L-shaped outline drawn counter-clockwise.
  outline = [[0, 0, 0], [100, 0, 0], [100, 40, 0], [40, 40, 0], [40, 100, 0], [0, 100, 0], [0, 0, 0]]
  path = build_path(outline, closed: true)
  assert Placement.lateral_points_inward?(path) == true
  assert Placement.lateral_points_inward?(build_path(outline.reverse, closed: true)) == false
end

test 'alternate flip is applied on top of facing' do
  path = build_path(CCW_SQUARE, closed: true)
  settings = settings_with(distribution: :count, count: 4, orientation: :flat,
                           facing: :outward, alternate_flip: true)
  centre = Geom::Point3d.new(50, 50, 0)
  placed = place(path, settings, instance_with)
  assert !lateral_towards_centre?(placed[0], centre)
  assert lateral_towards_centre?(placed[1], centre)
end


# --- follow path plane ------------------------------------------------------

WALL_LOOP = [[0, 0, 0], [100, 0, 0], [100, 0, 100], [0, 0, 100], [0, 0, 0]].freeze

test 'path_up is the plane normal, turned upward when it can be' do
  assert_vector [0, 0, 1], Placement.path_up(build_path(CCW_SQUARE, closed: true))
  assert_vector [0, 0, 1], Placement.path_up(build_path(CW_SQUARE, closed: true))
  assert_vector [0, 0, 1], Placement.path_up(build_path([[0, 0, 0], [100, 0, 0]]))
end

test 'a loop on a wall has a horizontal plane normal' do
  up = Placement.path_up(build_path(WALL_LOOP, closed: true))
  assert (up.z.abs < 1.0e-9) && (up.y.abs - 1.0).abs < 1.0e-9, up.inspect
end

test 'planar orientation keeps the copy in the wall and its Z along the wall normal' do
  path = build_path(WALL_LOOP, closed: true)
  settings = settings_with(distribution: :count, count: 4, orientation: :planar)
  placed = place(path, settings, instance_with)
  placed.each do |t|
    assert t.zaxis.z.abs < 1.0e-9, "Z should lie in plan, got #{t.zaxis}"
    assert t.xaxis.y.abs < 1.0e-9, "X should stay in the wall, got #{t.xaxis}"
  end
end

test 'planar orientation on a horizontal loop is the flat orientation' do
  path = build_path(CCW_SQUARE, closed: true)
  settings = settings_with(distribution: :count, count: 4)
  flat = place(path, settings_with(distribution: :count, count: 4, orientation: :flat), instance_with)
  planar = place(path, settings_with(distribution: :count, count: 4, orientation: :planar), instance_with)
  flat.zip(planar).each do |a, b|
    assert_vector a.xaxis.to_a, b.xaxis
    assert_vector a.zaxis.to_a, b.zaxis
  end
end

test 'facing works on a wall loop in planar mode, where flat mode cannot' do
  path = build_path(WALL_LOOP, closed: true)
  centre = Geom::Point3d.new(50, 0, 50)
  inward = place(path, settings_with(distribution: :count, count: 4, orientation: :planar, facing: :inward), instance_with)
  outward = place(path, settings_with(distribution: :count, count: 4, orientation: :planar, facing: :outward), instance_with)
  inward.each { |t| assert t.yaxis.dot(centre - t.origin) > 0, 'expected +Y into the loop' }
  outward.each { |t| assert t.yaxis.dot(centre - t.origin) < 0, 'expected +Y out of the loop' }
end

test 'planar mode on a straight line falls back to flat' do
  path = build_path([[0, 0, 0], [0, 100, 0]])
  t = place(path, settings_with(distribution: :count, count: 1, orientation: :planar), instance_with).first
  assert_vector [0, 1, 0], t.xaxis
  assert_vector [0, 0, 1], t.zaxis
end

# --- ручной доворот отдельных копий ------------------------------------------

test 'a manual spin turns just the copy it was asked for' do
  path = build_path([[0, 0, 0], [300, 0, 0]])
  settings = settings_with(distribution: :count, count: 4, orientation: :flat)
  distances = Distribution.distances(path, settings)
  plain = Placement.transformations(path, distances, settings, instance_with)
  spun = Placement.transformations(path, distances, settings, instance_with, spins: { 1 => 90.0 })

  assert_vector plain[0].xaxis.to_a, spun[0].xaxis
  assert_vector [0, 1, 0], spun[1].xaxis
  assert_vector plain[2].xaxis.to_a, spun[2].xaxis
  assert_point plain[1].origin.to_a, spun[1].origin
end

test 'manual spins are keyed by the global index across paths' do
  path = build_path([[0, 0, 0], [100, 0, 0]])
  settings = settings_with(distribution: :count, count: 2, orientation: :flat)
  distances = Distribution.distances(path, settings)
  second = Placement.transformations(path, distances, settings, instance_with,
                                     index_offset: 2, spins: { 3 => 180.0 })
  assert_vector [1, 0, 0], second[0].xaxis
  assert_vector [-1, 0, 0], second[1].xaxis
end

test 'a manual spin adds on top of the other rotations' do
  path = build_path([[0, 0, 0], [100, 0, 0]])
  settings = settings_with(distribution: :count, count: 2, orientation: :flat,
                           extra_angle: 90.0, alternate_flip: true)
  distances = Distribution.distances(path, settings)
  spun = Placement.transformations(path, distances, settings, instance_with, spins: { 0 => 90.0 })
  # 90 extra + 90 manual = 180
  assert_vector [-1, 0, 0], spun[0].xaxis
end

# --- поручень ----------------------------------------------------------------

test 'a rectangular profile is four points around the path line' do
  s = settings_with(rail: true, rail_width: 40.0, rail_height: 20.0, rail_shape: :rect)
  assert_equal [[-20.0, -10.0], [20.0, -10.0], [20.0, 10.0], [-20.0, 10.0]], Railing.profile(s)
end

test 'a round profile is a closed ring of the requested size' do
  s = settings_with(rail: true, rail_width: 40.0, rail_height: 40.0, rail_shape: :round)
  points = Railing.profile(s)
  assert_equal Railing::ROUND_SEGMENTS, points.size
  points.each { |u, v| assert_close 20.0, Math.sqrt(u * u + v * v), 1.0e-9 }
end

test 'alignment puts the profile on the line or wholly to one side' do
  base = { rail: true, rail_width: 40.0, rail_height: 20.0 }
  centred = Railing.profile(settings_with(**base, rail_align: :center))
  outward = Railing.profile(settings_with(**base, rail_align: :outward))
  inward = Railing.profile(settings_with(**base, rail_align: :inward))

  assert_equal(-20.0, centred.map(&:first).min)
  assert_equal 20.0, centred.map(&:first).max
  assert_equal 0.0, outward.map(&:first).min
  assert_equal 40.0, outward.map(&:first).max
  assert_equal(-40.0, inward.map(&:first).min)
  assert_equal 0.0, inward.map(&:first).max
end

test 'rise lifts the profile off the path line' do
  s = settings_with(rail: true, rail_width: 40.0, rail_height: 20.0, rail_rise: 100.0)
  points = Railing.profile(s)
  assert_equal 90.0, points.map(&:last).min
  assert_equal 110.0, points.map(&:last).max
end

test 'a section sits in the mitre plane at a corner' do
  path = build_path([[0, 0, 0], [100, 0, 0], [100, 100, 0]])
  s = settings_with(rail: true, rail_width: 20.0, rail_height: 20.0)
  rings = Railing.sections(path, s)
  assert_equal 3, rings.size

  corner = Geom::Point3d.new(100, 0, 0)
  bisector = Geom::Vector3d.new(1, 1, 0).normalize
  rings[1].each do |p|
    assert_close 0.0, (p - corner).dot(bisector), 1.0e-9, 'point left the mitre plane'
  end
end

test 'the profile keeps its width through a corner' do
  path = build_path([[0, 0, 0], [100, 0, 0], [100, 100, 0]])
  s = settings_with(rail: true, rail_width: 20.0, rail_height: 20.0)
  rings = Railing.sections(path, s)
  # Прямые сечения шириной 20; косое на срезе длиннее ровно в 1/cos(45).
  assert_close 20.0, rings[0][0].distance(rings[0][1]), 1.0e-6
  assert_close 20.0 * Math.sqrt(2), rings[1][0].distance(rings[1][1]), 1.0e-6
end

test 'extending the ends adds sections beyond the path' do
  path = build_path([[0, 0, 0], [100, 0, 0]])
  base = { rail: true, rail_width: 10.0, rail_height: 10.0 }
  plain = Railing.sections(path, settings_with(**base))
  longer = Railing.sections(path, settings_with(**base, rail_extend: 25.0))
  assert_equal 2, plain.size
  assert_equal 4, longer.size
  assert_close(-25.0, longer.first.map(&:x).min, 1.0e-6)
  assert_close 125.0, longer.last.map(&:x).max, 1.0e-6
end

test 'a closed loop gets one section per vertex and no duplicate at the seam' do
  square = build_path([[0, 0, 0], [100, 0, 0], [100, 100, 0], [0, 100, 0], [0, 0, 0]], closed: true)
  rings = Railing.sections(square, settings_with(rail: true, rail_width: 10.0, rail_height: 10.0))
  assert_equal 4, rings.size
end

test 'no railing is produced when it is switched off or has no size' do
  path = build_path([[0, 0, 0], [100, 0, 0]])
  assert_equal [], Railing.sections(path, settings_with(rail: false))
  assert_equal [], Railing.sections(path, settings_with(rail: true, rail_width: 0.0))
end

test 'the skin closes an open run with two caps' do
  path = build_path([[0, 0, 0], [100, 0, 0], [100, 100, 0]])
  entities = Sketchup::Entities.new
  group = Railing.build(entities, path, settings_with(rail: true, rail_width: 20.0, rail_height: 20.0))
  # Два участка по четыре боковых грани плюс два торца.
  assert_equal 10, group.entities.faces.size
end

test 'a closed loop is skinned without caps' do
  square = build_path([[0, 0, 0], [100, 0, 0], [100, 100, 0], [0, 100, 0], [0, 0, 0]], closed: true)
  entities = Sketchup::Entities.new
  group = Railing.build(entities, square, settings_with(rail: true, rail_width: 20.0, rail_height: 20.0))
  assert_equal 16, group.entities.faces.size
end
