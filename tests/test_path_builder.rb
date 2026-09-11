# frozen_string_literal: true

test 'unwelded edges given out of order are ordered into one path' do
  # The whole point: no Weld step, no single-Curve requirement.
  edges = build_edges([
                        [[200, 0, 0], [300, 0, 0]],
                        [[0, 0, 0], [100, 0, 0]],
                        [[200, 0, 0], [100, 0, 0]]
                      ])

  paths = PathBuilder.from_entities(edges)
  assert_equal 1, paths.size

  path = paths.first
  assert_equal 4, path.points.size
  assert_close 300.0, path.length
  assert !path.closed?

  xs = path.points.map { |point| point.x.round(6) }
  assert(xs == [0.0, 100.0, 200.0, 300.0] || xs == [300.0, 200.0, 100.0, 0.0],
         "points not in path order: #{xs.inspect}")
end

test 'reversed edges do not misplace the ordering' do
  # 2.200 patched this for Curves only; here it falls out of the walk.
  edges = build_edges([
                        [[100, 0, 0], [0, 0, 0]],
                        [[100, 0, 0], [100, 100, 0]],
                        [[100, 200, 0], [100, 100, 0]]
                      ])

  path = PathBuilder.from_entities(edges).first
  assert_equal 4, path.points.size
  assert_close 300.0, path.length
end

test 'a closed loop is detected and keeps its seam point' do
  edges = build_edges([
                        [[0, 0, 0], [100, 0, 0]],
                        [[100, 0, 0], [100, 100, 0]],
                        [[100, 100, 0], [0, 100, 0]],
                        [[0, 100, 0], [0, 0, 0]]
                      ])

  path = PathBuilder.from_entities(edges).first
  assert path.closed?, 'loop not detected as closed'
  assert_equal 5, path.points.size
  assert_close 400.0, path.length
end

test 'a branch splits into separate paths rather than guessing' do
  edges = build_edges([
                        [[0, 0, 0], [100, 0, 0]],
                        [[100, 0, 0], [200, 0, 0]],
                        [[100, 0, 0], [100, 100, 0]]
                      ])

  paths = PathBuilder.from_entities(edges)
  assert_equal 3, paths.size
  paths.each { |path| assert_equal 2, path.points.size }
end

test 'two separate chains come back as two paths' do
  edges = build_edges([
                        [[0, 0, 0], [100, 0, 0]],
                        [[100, 0, 0], [200, 0, 0]],
                        [[0, 500, 0], [100, 500, 0]]
                      ])

  paths = PathBuilder.from_entities(edges).sort_by(&:length)
  assert_equal 2, paths.size
  assert_close 100.0, paths[0].length
  assert_close 200.0, paths[1].length
end

test 'a seed edge grows through neighbours until connectivity is ambiguous' do
  edges = build_edges([
                        [[0, 0, 0], [100, 0, 0]],
                        [[100, 0, 0], [200, 0, 0]],
                        [[200, 0, 0], [300, 0, 0]]
                      ])

  path = PathBuilder.from_seed_edge(edges[1])
  assert_equal 4, path.points.size
  assert_close 300.0, path.length
end

test 'growth stops at a junction instead of leaking into a branch' do
  edges = build_edges([
                        [[0, 0, 0], [100, 0, 0]],
                        [[100, 0, 0], [200, 0, 0]],
                        [[100, 0, 0], [100, 100, 0]]
                      ])

  path = PathBuilder.from_seed_edge(edges[0])
  assert_equal 2, path.points.size
  assert_close 100.0, path.length
end

test 'a face contributes its outer loop' do
  edges = build_edges([
                        [[0, 0, 0], [100, 0, 0]],
                        [[100, 0, 0], [100, 100, 0]],
                        [[100, 100, 0], [0, 100, 0]],
                        [[0, 100, 0], [0, 0, 0]]
                      ])
  face = Sketchup::Face.new(edges)

  path = PathBuilder.from_entities([face]).first
  assert path.closed?
  assert_close 400.0, path.length
end

test 'a curve contributes all of its edges' do
  edges = build_edges([
                        [[0, 0, 0], [10, 0, 0]],
                        [[10, 0, 0], [20, 5, 0]]
                      ])
  curve = Sketchup::Curve.new(edges)

  path = PathBuilder.from_entities([curve]).first
  assert_equal 3, path.points.size
end

test 'a non-edge seed is refused rather than raising' do
  assert_equal nil, PathBuilder.from_seed_edge(nil)
  assert_equal [], PathBuilder.from_entities([])
end
