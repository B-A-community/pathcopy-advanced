# frozen_string_literal: true

module BACommunity
  module PathCopyAdvanced
    %w[constants path path_builder distribution placement copier settings icons menus tool]
      .each { |file| Sketchup.require(File.join(__dir__, file)) }

    # Shared options instance, so the toolbar menu and the running tool edit the
    # same state instead of drifting apart.
    def self.settings
      @settings ||= Settings.load
    end

    def self.start
      Sketchup.active_model.select_tool(Tool.new(settings))
    end

    unless defined?(@ui_built)
      @ui_built = true

      command = UI::Command.new(PLUGIN_NAME) { start }
      command.tooltip = PLUGIN_NAME
      command.status_bar_text = 'Copy a group or component along a path'
      command.small_icon = Icons.toolbar('pca_small')
      command.large_icon = Icons.toolbar('pca_large')

      menu = UI.menu('Extensions').add_submenu(PLUGIN_NAME)
      menu.add_item(command)
      menu.add_separator
      menu.add_item('Offsets and rotation...') { Menus.offsets_dialog(settings) { settings.save } }
      menu.add_item('Randomisation...') { Menus.jitter_dialog(settings) { settings.save } }
      menu.add_item('Tag for copies...') { Menus.tag_dialog(settings) { settings.save } }
      menu.add_separator
      menu.add_item('Reset options') do
        Settings::DEFAULTS.each { |key, value| settings.send("#{key}=", value) }
        settings.sanitize!.save
      end

      toolbar = UI::Toolbar.new(PLUGIN_NAME)
      toolbar.add_item(command)
      toolbar.restore
    end
  end
end
