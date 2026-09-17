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

test 'exactly on a sharp corner the copy follows the segment leaving it' do
  # A fence post at a corner sits square to the next rail, not on the bisector.
  path = build_path([[0, 0, 0], [100, 0, 0], [100, 100, 0]])
  _, tangent = path.sample(100)
  assert_vector [0, 1, 0], tangent
end

test 'on a gentle bend the tangent is still blended so arcs stay smooth' do
  # 20 degrees between segments: well under the 45 degree corner threshold.
  a = 20.0 * Math::PI / 180.0
  path = build_path([[0, 0, 0], [100, 0, 0], [100 + 100 * Math.cos(a), 100 * Math.sin(a), 0]])
  _, tangent = path.sample(100)
  half = a / 2.0
  assert_vector [Math.cos(half), Math.sin(half), 0], tangent, 1.0e-6
end

test 'every corner of a closed loop gets the same rule, seam included' do
  square = build_path([[0, 0, 0], [100, 0, 0], [100, 100, 0], [0, 100, 0], [0, 0, 0]], closed: true)
  headings = [0, 100, 200, 300].map { |d| square.sample(d).last }
  assert_vector [1, 0, 0], headings[0]   # seam: leaving along the first segment
  assert_vector [0, 1, 0], headings[1]
  assert_vector [-1, 0, 0], headings[2]
  assert_vector [0, -1, 0], headings[3]
end

test 'the open end of a path keeps the incoming direction' do
  path = build_path([[0, 0, 0], [100, 0, 0], [100, 100, 0]])
  _, tangent = path.sample(200)
  assert_vector [0, 1, 0], tangent
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

test 'a reversed path keeps its length and walks the other way' do
  path = build_path([[0, 0, 0], [100, 0, 0], [100, 100, 0]])
  back = path.reverse
  assert_close path.length, back.length
  assert_point [100, 100, 0], back.points.first
  assert_point [0, 0, 0], back.points.last
  _, tangent = back.sample(50)
  assert_vector [0, -1, 0], tangent
end

test 'reversing a closed path keeps it closed' do
  square = build_path([[0, 0, 0], [100, 0, 0], [100, 100, 0], [0, 100, 0], [0, 0, 0]], closed: true)
  assert square.reverse.closed?
  assert_equal 5, square.reverse.points.size
end

test 'reversing swaps which end the start offset is measured from' do
  path = build_path([[0, 0, 0], [100, 0, 0]])
  settings = settings_with(distribution: :count, count: 1, start_offset: 30.0, end_offset: 0.0)
  # count 1 centres in the usable span: span is 70 either way, but starts elsewhere
  forward = Distribution.distances(path, settings).first
  backward = Distribution.distances(path.reverse, settings).first
  assert_point [65, 0, 0], path.sample(forward).first
  assert_point [35, 0, 0], path.reverse.sample(backward).first
end
