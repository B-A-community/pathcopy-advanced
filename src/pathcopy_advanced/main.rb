# frozen_string_literal: true

module BACommunity
  module PathCopyAdvanced
    %w[lang constants path path_builder distribution placement railing copier settings icons
       about panel menus tool]
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
      command.tooltip = t(:tip_tool)
      command.status_bar_text = t(:st_tool)
      command.small_icon = Icons.toolbar('pca_small')
      command.large_icon = Icons.toolbar('pca_large')

      panel_command = UI::Command.new(t(:menu_panel)) do
        settings.show_panel = true
        settings.save
        Panel.show(settings)
      end
      panel_command.tooltip = t(:tip_panel)
      panel_command.status_bar_text = t(:st_panel)
      panel_command.small_icon = Icons.toolbar('pca_panel_small')
      panel_command.large_icon = Icons.toolbar('pca_panel_large')

      menu = UI.menu('Extensions').add_submenu(PLUGIN_NAME)
      menu.add_item(command)
      menu.add_item(panel_command)
      menu.add_separator
      menu.add_item(t(:menu_about)) { About.show }
      menu.add_item(t(:menu_reset)) do
        Settings::DEFAULTS.each { |key, value| settings.send("#{key}=", value) }
        settings.sanitize!.save
        Panel.push
      end

      toolbar = UI::Toolbar.new(PLUGIN_NAME)
      toolbar.add_item(command)
      toolbar.add_item(panel_command)
      toolbar.restore
    end
  end
end
