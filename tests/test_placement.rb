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
