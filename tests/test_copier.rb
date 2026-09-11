# frozen_string_literal: true

def three_transformations
  [[0, 0, 0], [50, 0, 0], [100, 0, 0]].map do |coordinates|
    Geom::Transformation.translation(point(*coordinates))
  end
end

test 'copies are created at the given transformations inside one operation' do
  model = Sketchup::Model.new
  created = Copier.run(model, [instance_with], three_transformations, settings_with)

  assert_equal 3, created.size
  assert_point [50, 0, 0], created[1].transformation.origin
  assert_equal 1, model.operations.size
  assert_equal :committed, model.operations.first[:outcome]
end

test 'the operation disables the UI, which the original never did' do
  model = Sketchup::Model.new
  Copier.run(model, [instance_with], three_transformations, settings_with)
  assert_equal true, model.operations.first[:disable_ui]
end

test 'the first run is a normal operation and later tweaks merge into it' do
  # This replaces the original's Sketchup.undo call, which reached into the
  # application undo stack and could roll back unrelated work.
  model = Sketchup::Model.new
  Copier.run(model, [instance_with], three_transformations, settings_with, merge_with_previous: false)
  assert_equal false, model.operations.last[:transparent]

  Copier.run(model, [instance_with], three_transformations, settings_with, merge_with_previous: true)
  assert_equal true, model.operations.last[:transparent]
end

test 'a component copy keeps material, tag and name' do
  source = instance_with
  source.material = 'Oak'
  source.layer = 'Landscape'
  source.name = 'Bollard'

  model = Sketchup::Model.new
  created = Copier.run(model, [source], three_transformations, settings_with)

  created.each do |copy|
    assert_equal 'Oak', copy.material
    assert_equal 'Landscape', copy.layer
    assert_equal 'Bollard', copy.name
  end
end

test 'a group copy keeps its group nature and gets the new transformation' do
  source = instance_with(group: true)
  source.owner = Sketchup::Entities.new

  model = Sketchup::Model.new
  created = Copier.run(model, [source], three_transformations, settings_with)

  assert_equal 3, created.size
  created.each { |copy| assert copy.is_a?(Sketchup::Group), 'group copy lost its type' }
  assert_point [100, 0, 0], created[2].transformation.origin
end

test 'several sources alternate along the run' do
  first = instance_with
  second = instance_with
  model = Sketchup::Model.new

  transformations = (0..3).map { |i| Geom::Transformation.translation(point(i * 10, 0, 0)) }
  created = Copier.run(model, [first, second], transformations, settings_with)

  assert_equal first.definition, created[0].definition
  assert_equal second.definition, created[1].definition
  assert_equal first.definition, created[2].definition
  assert_equal second.definition, created[3].definition
end

test 'a requested tag is created and applied' do
  model = Sketchup::Model.new
  created = Copier.run(model, [instance_with], three_transformations, settings_with(tag_name: 'Trees'))

  assert model.layers['Trees'], 'tag was not created'
  created.each { |copy| assert_equal 'Trees', copy.layer.name }
end

test 'grouping the result returns a single wrapper' do
  model = Sketchup::Model.new
  created = Copier.run(model, [instance_with], three_transformations, settings_with(group_result: true))

  assert_equal 1, created.size
  assert_equal 3, created.first.contents.size
  assert created.first.name.include?('PathCopy')
end

test 'a failure aborts the operation instead of leaving it open' do
  model = Sketchup::Model.new
  model.active_entities.raise_on_add = true

  raised = false
  begin
    Copier.run(model, [instance_with], three_transformations, settings_with)
  rescue ArgumentError
    raised = true
  end

  assert raised, 'the error should propagate'
  assert_equal :aborted, model.operations.last[:outcome]
end

test 'erasing a batch removes exactly those entities' do
  model = Sketchup::Model.new
  created = Copier.run(model, [instance_with], three_transformations, settings_with)
  assert_equal 3, model.active_entities.items.size

  Copier.erase(model, created)
  assert_equal 0, model.active_entities.items.size
  created.each { |entity| assert !entity.valid?, 'entity should be gone' }
end

test 'erasing an already-erased batch is a no-op' do
  model = Sketchup::Model.new
  created = Copier.run(model, [instance_with], three_transformations, settings_with)
  Copier.erase(model, created)
  before = model.operations.size

  Copier.erase(model, created)
  assert_equal before, model.operations.size
end

test 'nothing to do means no operation is opened at all' do
  model = Sketchup::Model.new
  assert_equal [], Copier.run(model, [], three_transformations, settings_with)
  assert_equal [], Copier.run(model, [instance_with], [], settings_with)
  assert_equal 0, model.operations.size
end

test 'the tool and menu code loads without unresolved constants' do
  assert defined?(BACommunity::PathCopyAdvanced::Tool)
  assert defined?(BACommunity::PathCopyAdvanced::Menus)
  assert defined?(BACommunity::PathCopyAdvanced::Icons)
  assert Tool.instance_methods.include?(:onUserText)
  assert Tool.instance_methods.include?(:draw)
  assert Tool.instance_methods.include?(:enableVCB?)
end
