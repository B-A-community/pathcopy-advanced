# frozen_string_literal: true

# A stand-in for the running tool: records what the panel asks of it.
class FakeTool
  attr_reader :changes

  def initialize
    @changes = 0
  end

  def settings_changed
    @changes += 1
  end

  def panel_status
    'stub status'
  end
end

def fresh_panel(settings = settings_with)
  Panel.instance_variable_set(:@dialog, nil)
  Panel.instance_variable_set(:@tool, nil)
  Panel.show(settings)
  [Panel.instance_variable_get(:@dialog), settings]
end

test 'showing the panel opens the dialog on the html file and pushes the state' do
  dialog, = fresh_panel
  assert dialog.visible?
  assert dialog.file.end_with?('panel.html')
  assert dialog.scripts.last.include?('pca.update('), dialog.scripts.last
end

test 'the payload formats lengths in model units and carries the option lists' do
  dialog, settings = fresh_panel(settings_with(spacing: 48.0, jitter_scale: 0.25, extra_angle: 90.0))
  json = dialog.scripts.last[/pca\.update\((.*)\);/m, 1]
  data = JSON.parse(json)
  assert_equal '48.000"', data['spacing']
  assert_equal 25.0, data['jitter_scale']
  assert_equal 90.0, data['extra_angle']
  assert_equal 'spacing', data['distribution']
  assert_equal %w[spacing count fit segments vertices], data['options']['distribution'].map(&:first)
  assert data['options']['distribution'].map(&:last).include?('Подгонка по сегментам')
  assert data['status'].include?('не запущен')
end

test 'a field change parses by type and lands in the settings' do
  dialog, settings = fresh_panel
  set = dialog.callbacks['set']
  set.call(nil, 'distribution', 'segments')
  set.call(nil, 'spacing', '2\'')
  set.call(nil, 'count', '12')
  set.call(nil, 'jitter_scale', '30')
  set.call(nil, 'jitter', 'true')
  set.call(nil, 'extra_angle', '90')
  set.call(nil, 'tag_name', 'Ограждение')
  assert_equal :segments, settings.distribution
  assert_close 24.0, settings.spacing
  assert_equal 12, settings.count
  assert_close 0.3, settings.jitter_scale
  assert_equal true, settings.jitter
  assert_close 90.0, settings.extra_angle
  assert_equal 'Ограждение', settings.tag_name
end

test 'an unparsable length is refused and the panel is re-synced instead' do
  dialog, settings = fresh_panel(settings_with(spacing: 48.0))
  before = dialog.scripts.size
  dialog.callbacks['set'].call(nil, 'spacing', 'abc')
  assert_close 48.0, settings.spacing
  assert dialog.scripts.size > before, 'expected a push back to the panel'
end

test 'an unknown key is ignored' do
  dialog, settings = fresh_panel
  dialog.callbacks['set'].call(nil, 'no_such_key', '1')
  assert_equal Settings::DEFAULTS[:spacing], settings.spacing
end

test 'with a tool attached a change asks the tool to rebuild' do
  dialog, settings = fresh_panel
  tool = FakeTool.new
  Panel.attach(tool, settings)
  dialog.callbacks['set'].call(nil, 'count', '7')
  assert_equal 1, tool.changes
  Panel.detach(tool)
  dialog.callbacks['set'].call(nil, 'count', '8')
  assert_equal 1, tool.changes, 'detached tool must not be poked'
end

test 'the status line comes from the tool while it is attached' do
  dialog, settings = fresh_panel
  Panel.attach(FakeTool.new, settings)
  data = JSON.parse(dialog.scripts.last[/pca\.update\((.*)\);/m, 1])
  assert_equal 'stub status', data['status']
end

test 'reset restores defaults but keeps the panel open' do
  dialog, settings = fresh_panel(settings_with(count: 33, jitter: true, show_panel: true))
  dialog.callbacks['reset'].call(nil)
  assert_equal Settings::DEFAULTS[:count], settings.count
  assert_equal false, settings.jitter
  assert_equal true, settings.show_panel
end

test 'closing the panel remembers not to reopen it' do
  dialog, settings = fresh_panel(settings_with(show_panel: true))
  dialog.close
  assert_equal false, settings.show_panel
end

test 'settings symbols round-trip through the panel as strings' do
  dialog, settings = fresh_panel
  dialog.callbacks['set'].call(nil, 'orientation', 'planar')
  dialog.callbacks['set'].call(nil, 'facing', 'inward')
  assert_equal :planar, settings.orientation
  assert_equal :inward, settings.facing
end
