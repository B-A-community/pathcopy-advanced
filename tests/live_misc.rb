module PCAMisc
  REPORT = []
  module_function
  def check(n, c, d = '') = REPORT << [(c ? 'PASS' : 'FAIL'), n, d.to_s]

  # Duck-typed stand-in for UI::Menu, which cannot be instantiated from Ruby.
  class FakeMenu
    attr_reader :items, :subs, :procs
    def initialize; @items = []; @subs = {}; @procs = {}; @n = 0; end
    def add_item(label, &blk); @n += 1; @items << [label, blk, @n]; @n; end
    def add_separator; @items << [:sep, nil, nil]; end
    def add_submenu(label); @subs[label] = FakeMenu.new; end
    def set_validation_proc(id, &blk); @procs[id] = blk; end
  end

  def run
    REPORT.clear
    ns = BACommunity::PathCopyAdvanced

    # --- context menu ---------------------------------------------------
    settings = ns::Settings.new
    settings.distribution = :count
    settings.jitter = false
    menu = FakeMenu.new
    fired = 0
    ns::Menus.build(menu, settings) { fired += 1 }

    check('menu has the four option submenus',
          %w[Distribution Orientation Alignment Anchor].all? { |k| menu.subs.key?(k) },
          menu.subs.keys.inspect)
    dist = menu.subs['Distribution']
    check('distribution submenu lists every mode', dist.items.size == ns::DISTRIBUTION_MODES.size, dist.items.size)
    labels = dist.items.map(&:first)
    count_id = dist.items.find { |l, _, _| l == 'Count' }.last
    spacing_id = dist.items.find { |l, _, _| l == 'Spacing' }.last
    check('validation proc marks the current mode with MF_CHECKED',
          dist.procs[count_id].call == MF_CHECKED && dist.procs[spacing_id].call == MF_UNCHECKED)
    dist.items.find { |l, _, _| l == 'Fit spacing' }[1].call
    check('choosing a mode from the menu updates settings and fires the callback',
          settings.distribution == :fit && fired == 1, "#{settings.distribution} fired=#{fired}")
    toggle = menu.items.find { |l, _, _| l == 'Randomise placement' }
    toggle[1].call
    check('a toggle flips its setting', settings.jitter == true)
    check('toggle validation reflects the new state',
          menu.procs[toggle.last].call == MF_CHECKED)
    reset = menu.items.find { |l, _, _| l == 'Reset all options' }
    reset[1].call
    check('reset restores defaults', settings.distribution == :spacing && settings.jitter == false)

    # --- persistence ----------------------------------------------------
    probe = ns::Settings.new
    probe.distribution = :vertices
    probe.spacing = 123.456
    probe.orientation = :tangent3d
    probe.anchor = :bottom
    probe.tag_name = 'RoundTrip'
    probe.jitter_scale = 0.33
    probe.save
    back = ns::Settings.load
    check('settings survive a write_default / read_default round trip',
          back.distribution == :vertices && (back.spacing - 123.456).abs < 1.0e-9 &&
          back.orientation == :tangent3d && back.anchor == :bottom &&
          back.tag_name == 'RoundTrip' && (back.jitter_scale - 0.33).abs < 1.0e-9,
          [back.distribution, back.spacing, back.orientation, back.anchor, back.tag_name, back.jitter_scale].inspect)
    check('symbols come back as symbols, not strings', back.distribution.is_a?(Symbol))
    ns::Settings.new.save   # leave the user with defaults again
    check('defaults restored after the probe', ns::Settings.load.distribution == :spacing)

    # --- icons ----------------------------------------------------------
    small = ns::Icons.toolbar('pca_small')
    large = ns::Icons.toolbar('pca_large')
    check('toolbar icons resolve to files that exist', File.exist?(small) && File.exist?(large), [small, large].inspect)
    check('on Windows / SU2016+ the vector icon is chosen', small.end_with?('.svg') && large.end_with?('.svg'))
    check('cursor creation returns a real cursor id', ns::Icons.cursor('pca_cursor', 4, 4).to_i > 0)
    check('instructor directory is where the tool says', File.exist?(File.join(ns::Tool.new.getInstructorContentDirectory, 'index.html')))

    passed = REPORT.count { |r| r[0] == 'PASS' }
    lines = REPORT.map { |s, n, d| "#{s}  #{n}#{d.empty? ? '' : "  [#{d}]"}" }
    lines << ''
    lines << "#{REPORT.size} checks, #{passed} passed, #{REPORT.size - passed} failed"
    File.write(File.expand_path('../build/live_misc_result.txt', __dir__), lines.join("\n"))
    lines.last
  end
end
begin
  PCAMisc.run
rescue Exception => e
  File.write(File.expand_path('../build/live_misc_result.txt', __dir__),
             ["CRASH: #{e.class}: #{e.message}", *e.backtrace.first(12)].join("\n"))
end

