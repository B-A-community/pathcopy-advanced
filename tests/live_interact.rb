module PCAInteract
  REPORT = []
  BASE = Geom::Point3d.new(6000, 0, 0)
  module_function
  def model = Sketchup.active_model
  def ents = model.active_entities
  def at(dx, dy, dz = 0) = Geom::Point3d.new(BASE.x + dx, BASE.y + dy, BASE.z + dz)
  def check(n, c, d = '') = REPORT << [(c ? 'PASS' : 'FAIL'), n, d.to_s]

  def run
    REPORT.clear
    view = model.active_view

    # Fresh, isolated path + source.
    edges = []
    edges << ents.add_line(at(0, 0), at(400, 0))
    edges << ents.add_line(at(400, 0), at(400, 300))
    source = ents.add_instance(model.definitions['PCA_Bench'], Geom::Transformation.new(at(-200, 0)))

    settings = BACommunity::PathCopyAdvanced::Settings.new
    settings.distribution = :spacing
    settings.spacing = 100.0
    settings.orientation = :flat
    settings.anchor = :bottom

    model.selection.clear
    model.selection.add(edges)
    tool = BACommunity::PathCopyAdvanced::Tool.new(settings)
    model.select_tool(tool)
    check('tool picked up the two-segment path',
          tool.instance_variable_get(:@paths).size == 1)

    before = ents.length

    # 1. Simulate the object click.
    tool.instance_variable_set(:@sources, [source])
    tool.send(:commit)
    first = tool.instance_variable_get(:@created)
    check('click placed 8 copies at spacing 100', first.size == 8, first.size)
    check('state advanced to :placed',
          tool.instance_variable_get(:@state) == :placed,
          tool.instance_variable_get(:@state).inspect)
    after_first = ents.length

    # 2. Retype the spacing - the exact move that broke undo in the original.
    # to_l reads the value in the model's own units - mm here, not inches - so
    # the expected count is derived rather than hardcoded.
    path_length = tool.instance_variable_get(:@paths).first.length
    tool.onUserText('200', view)
    second = tool.instance_variable_get(:@created)
    expected = (path_length / settings.spacing).floor + 1
    check('retyping a value rebuilt the copies at the new spacing',
          second.size == expected, "got #{second.size}, expected #{expected}")
    check('the typed value was read in model units (mm)',
          (settings.spacing - 200.mm).abs < 1.0e-6,
          "#{settings.spacing.round(4)} in = #{(settings.spacing * 25.4).round(1)} mm")
    check('old copies were removed, not stacked',
          ents.length == before + second.size, "#{before} + #{second.size} vs #{ents.length}")
    check('the previous batch is really gone', first.none?(&:valid?))

    # 3. Switch to count mode via the value box.
    tool.onUserText('12x', view)
    third = tool.instance_variable_get(:@created)
    check('typing 12x switched to count mode and placed 12', third.size == 12, third.size)
    check('settings followed the value box', settings.distribution == :count, settings.distribution.inspect)

    # 4. Cycle orientation with the arrow key.
    before_orientation = settings.orientation
    tool.onKeyUp(VK_UP, 1, 0, view)
    check('Up arrow cycled the orientation',
          settings.orientation != before_orientation,
          "#{before_orientation} -> #{settings.orientation}")
    fourth = tool.instance_variable_get(:@created)
    check('copies were rebuilt after the key press', fourth.size == 12 && fourth.all?(&:valid?))

    # 5. Tab cycles the distribution mode.
    before_mode = settings.distribution
    tool.onKeyUp(9, 1, 0, view)
    check('Tab cycled the distribution mode',
          settings.distribution != before_mode, "#{before_mode} -> #{settings.distribution}")

    after_all = ents.length

    # 6. ONE undo must clear the whole interactive session.
    Sketchup.undo
    check('one undo cleared every copy from the session',
          ents.length == before, "#{after_first}/#{after_all} -> #{ents.length}, expected #{before}")

    # 7. Escape from a fresh session steps back without touching the model.
    model.selection.clear
    model.selection.add(edges.select(&:valid?))
    tool2 = BACommunity::PathCopyAdvanced::Tool.new(settings)
    model.select_tool(tool2)
    tool2.onCancel(0, view)
    check('Esc dropped the path and returned to stage one',
          tool2.instance_variable_get(:@state) == :path,
          tool2.instance_variable_get(:@state).inspect)
    check('Esc changed nothing in the model', ents.length == before, ents.length)

    model.select_tool(nil)
    passed = REPORT.count { |r| r[0] == 'PASS' }
    lines = REPORT.map { |s, n, d| "#{s}  #{n}#{d.empty? ? '' : "  [#{d}]"}" }
    lines << ''
    lines << "#{REPORT.size} checks, #{passed} passed, #{REPORT.size - passed} failed"
    File.write(File.expand_path('../build/live_interact_result.txt', __dir__), lines.join("\n"))
    "#{REPORT.size} checks, #{passed} passed, #{REPORT.size - passed} failed"
  end
end
begin
  PCAInteract.run
rescue Exception => e
  File.write(File.expand_path('../build/live_interact_result.txt', __dir__),
             ["CRASH: #{e.class}: #{e.message}", *e.backtrace.first(15)].join("\n"))
  "CRASH: #{e.class}: #{e.message}"
end

