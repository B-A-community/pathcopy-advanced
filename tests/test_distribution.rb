# frozen_string_literal: true

LINE = -> { build_path([[0, 0, 0], [100, 0, 0]]) }

test 'spacing mode places copies at both ends when the path divides evenly' do
  distances = Distribution.distances(LINE.call, settings_with(distribution: :spacing, spacing: 25.0))
  assert_equal [0.0, 25.0, 50.0, 75.0, 100.0], distances.map { |d| d.round(6) }
end

test 'spacing mode honours the alignment for the leftover length' do
  path = LINE.call

  from_start = Distribution.distances(path, settings_with(distribution: :spacing, spacing: 30.0, align: :start))
  assert_equal [0.0, 30.0, 60.0, 90.0], from_start.map { |d| d.round(6) }

  centered = Distribution.distances(path, settings_with(distribution: :spacing, spacing: 30.0, align: :center))
  assert_equal [5.0, 35.0, 65.0, 95.0], centered.map { |d| d.round(6) }

  from_end = Distribution.distances(path, settings_with(distribution: :spacing, spacing: 30.0, align: :end))
  assert_equal [10.0, 40.0, 70.0, 100.0], from_end.map { |d| d.round(6) }
end

test 'count mode spreads a fixed number of copies end to end' do
  distances = Distribution.distances(LINE.call, settings_with(distribution: :count, count: 5))
  assert_equal [0.0, 25.0, 50.0, 75.0, 100.0], distances.map { |d| d.round(6) }
end

test 'count mode with a single copy puts it in the middle' do
  distances = Distribution.distances(LINE.call, settings_with(distribution: :count, count: 1))
  assert_equal [50.0], distances.map { |d| d.round(6) }
end

test 'fit mode rounds the spacing so the path divides evenly' do
  distances = Distribution.distances(LINE.call, settings_with(distribution: :fit, spacing: 30.0))
  assert_equal 4, distances.size
  assert_close 0.0, distances.first
  assert_close 100.0, distances.last
  assert_close 100.0 / 3.0, distances[1]
end

test 'vertices mode places one copy per corner' do
  path = build_path([[0, 0, 0], [30, 0, 0], [30, 40, 0]])
  distances = Distribution.distances(path, settings_with(distribution: :vertices))
  assert_equal [0.0, 30.0, 70.0], distances.map { |d| d.round(6) }
end

test 'offsets shrink the usable span from both ends' do
  distances = Distribution.distances(
    LINE.call,
    settings_with(distribution: :spacing, spacing: 20.0, start_offset: 10.0, end_offset: 10.0)
  )
  assert_equal [10.0, 30.0, 50.0, 70.0, 90.0], distances.map { |d| d.round(6) }
end

test 'offsets larger than the path produce nothing rather than negative spans' do
  distances = Distribution.distances(
    LINE.call,
    settings_with(distribution: :spacing, spacing: 10.0, start_offset: 80.0, end_offset: 80.0)
  )
  assert_equal [], distances
end

test 'a closed loop drops the copy that would land back on the seam' do
  square = build_path([[0, 0, 0], [100, 0, 0], [100, 100, 0], [0, 100, 0], [0, 0, 0]], closed: true)
  assert square.closed?

  with_skip = Distribution.distances(square, settings_with(distribution: :spacing, spacing: 100.0, skip_seam: true))
  assert_equal [0.0, 100.0, 200.0, 300.0], with_skip.map { |d| d.round(6) }

  without_skip = Distribution.distances(square, settings_with(distribution: :spacing, spacing: 100.0, skip_seam: false))
  assert_equal 5, without_skip.size
end

test 'a closed loop in count mode spaces N copies over N intervals' do
  square = build_path([[0, 0, 0], [100, 0, 0], [100, 100, 0], [0, 100, 0], [0, 0, 0]], closed: true)
  distances = Distribution.distances(square, settings_with(distribution: :count, count: 4, skip_seam: true))
  assert_equal [0.0, 100.0, 200.0, 300.0], distances.map { |d| d.round(6) }
end

test 'vertices mode on a closed loop does not repeat the seam vertex' do
  square = build_path([[0, 0, 0], [100, 0, 0], [100, 100, 0], [0, 100, 0], [0, 0, 0]], closed: true)
  distances = Distribution.distances(square, settings_with(distribution: :vertices))
  assert_equal [0.0, 100.0, 200.0, 300.0], distances.map { |d| d.round(6) }
end

test 'zero and negative spacing produce nothing instead of raising' do
  path = LINE.call
  assert_equal [], Distribution.distances(path, settings_with(distribution: :spacing, spacing: 0.0))
  assert_equal [], Distribution.distances(path, settings_with(distribution: :spacing, spacing: -25.0))
end

test 'a tiny spacing is capped instead of hanging' do
  # This is the original's freeze: while(runningLength < 0) with no ceiling.
  # 100" at 0.001" would be 100,000 copies; the cap applies before allocation.
  distances = Distribution.distances(LINE.call, settings_with(distribution: :spacing, spacing: 0.001))
  assert_equal MAX_COPIES, distances.size
end

test 'a spacing below the geometric tolerance is refused outright' do
  distances = Distribution.distances(LINE.call, settings_with(distribution: :spacing, spacing: 0.000001))
  assert_equal [], distances
end

test 'settings sanitising replaces a sub-tolerance spacing with the default' do
  settings = settings_with(distribution: :spacing, spacing: 0.000001)
  settings.sanitize!
  assert_close Settings::DEFAULTS[:spacing], settings.spacing
end

test 'an absurd count is capped as well' do
  distances = Distribution.distances(LINE.call, settings_with(distribution: :count, count: 10_000_000))
  assert_equal MAX_COPIES, distances.size
end

test 'an invalid path yields nothing' do
  assert_equal [], Distribution.distances(build_path([[1, 1, 1], [1, 1, 1]]), settings_with)
end
