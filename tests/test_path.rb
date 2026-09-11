# frozen_string_literal: true

test 'straight path measures and samples by arc length' do
  path = build_path([[0, 0, 0], [100, 0, 0]])
  assert_close 100.0, path.length
  assert path.valid?
  assert !path.closed?

  origin, tangent = path.sample(25)
  assert_point [25, 0, 0], origin
  assert_vector [1, 0, 0], tangent
end

test 'sampling walks past a corner instead of stopping at the first segment' do
  # The original plugin only ever used one edge; this is the case it could not do.
  path = build_path([[0, 0, 0], [100, 0, 0], [100, 100, 0]])
  assert_close 200.0, path.length

  origin, tangent = path.sample(150)
  assert_point [100, 50, 0], origin
  assert_vector [0, 1, 0], tangent
end

test 'sampling clamps outside the path instead of extrapolating' do
  path = build_path([[0, 0, 0], [100, 0, 0]])
  assert_point [0, 0, 0], path.sample(-50).first
  assert_point [100, 0, 0], path.sample(500).first
end

test 'tangent at a corner is the average of the two segments' do
  path = build_path([[0, 0, 0], [100, 0, 0], [100, 100, 0]])
  _, tangent = path.sample(100)
  root = Math.sqrt(0.5)
  assert_vector [root, root, 0], tangent
end

test 'duplicate points are dropped so segments never have zero length' do
  path = build_path([[0, 0, 0], [0, 0, 0], [50, 0, 0], [50, 0, 0], [100, 0, 0]])
  assert_equal 3, path.points.size
  assert_close 100.0, path.length
end

test 'a degenerate path reports itself invalid rather than dividing by zero' do
  path = build_path([[7, 7, 7], [7, 7, 7]])
  assert !path.valid?
end

test 'a 3D path measures its true slope length' do
  path = build_path([[0, 0, 0], [0, 0, 100]])
  assert_close 100.0, path.length
  _, tangent = path.sample(50)
  assert_vector [0, 0, 1], tangent
end

test 'vertex distances line up with the cumulative lengths' do
  path = build_path([[0, 0, 0], [30, 0, 0], [30, 40, 0]])
  assert_equal [0.0, 30.0, 70.0], path.vertex_distances.map { |d| d.round(6) }
end
