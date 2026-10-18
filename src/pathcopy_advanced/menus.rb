# frozen_string_literal: true

module BACommunity
  module PathCopyAdvanced
    # The tool's right-click menu.
    #
    # Every option is reachable here, so nothing depends on remembering a
    # keyboard shortcut - the original hid its second mode behind "type 0 into
    # the measurement box" and never told anyone.
    module Menus
      module_function

      def build(menu, settings, &on_change)
        menu.add_item(PathCopyAdvanced.t(:menu_panel)) do
          settings.show_panel = true
          settings.save
          Panel.show(settings)
        end
        menu.add_separator

        %i[distribution orientation align anchor facing rail_align rail_shape].each do |group|
          radio_group(menu.add_submenu(PathCopyAdvanced.t(:"menu_#{group}")),
                      MODE_LISTS[group], PathCopyAdvanced.labels(group), settings, group, &on_change)
        end

        menu.add_separator
        toggle(menu, PathCopyAdvanced.t(:mi_rail), settings, :rail, &on_change)
        toggle(menu, PathCopyAdvanced.t(:mi_skip_seam), settings, :skip_seam, &on_change)
        toggle(menu, PathCopyAdvanced.t(:mi_reverse), settings, :reverse_path, &on_change)
        toggle(menu, PathCopyAdvanced.t(:mi_flip), settings, :alternate_flip, &on_change)
        toggle(menu, PathCopyAdvanced.t(:mi_jitter), settings, :jitter, &on_change)
        toggle(menu, PathCopyAdvanced.t(:mi_group), settings, :group_result, &on_change)

        menu.add_separator
        menu.add_item(PathCopyAdvanced.t(:mi_offsets)) { offsets_dialog(settings, &on_change) }
        menu.add_item(PathCopyAdvanced.t(:mi_jitter_dlg)) { jitter_dialog(settings, &on_change) }
        menu.add_item(PathCopyAdvanced.t(:mi_rail_dlg)) { rail_dialog(settings, &on_change) }
        menu.add_item(PathCopyAdvanced.t(:mi_tag)) { tag_dialog(settings, &on_change) }

        menu.add_separator
        menu.add_item(PathCopyAdvanced.t(:menu_reset)) do
          Settings::DEFAULTS.each { |key, value| settings.send("#{key}=", value) unless key == :show_panel }
          settings.sanitize!
          on_change&.call
        end
        menu
      end

      def radio_group(menu, modes, labels, settings, attribute, &on_change)
        modes.each do |mode|
          item = menu.add_item(labels[mode]) do
            settings.send("#{attribute}=", mode)
            settings.sanitize!
            on_change&.call
          end
          menu.set_validation_proc(item) do
            settings.send(attribute) == mode ? MF_CHECKED : MF_UNCHECKED
          end
        end
      end

      def toggle(menu, label, settings, attribute, &on_change)
        item = menu.add_item(label) do
          settings.send("#{attribute}=", !settings.send(attribute))
          settings.sanitize!
          on_change&.call
        end
        menu.set_validation_proc(item) do
          settings.send(attribute) ? MF_CHECKED : MF_UNCHECKED
        end
      end

      # --- dialogs -------------------------------------------------------

      def offsets_dialog(settings, &on_change)
        prompts = %i[p_start_offset p_end_offset p_offset_side p_offset_up p_extra_angle]
                  .map { |key| PathCopyAdvanced.t(key) }
        defaults = [
          length(settings.start_offset), length(settings.end_offset),
          length(settings.offset_lateral), length(settings.offset_vertical),
          settings.extra_angle.to_s
        ]
        result = UI.inputbox(prompts, defaults, PathCopyAdvanced.t(:dlg_offsets))
        return unless result

        settings.start_offset    = to_inches(result[0], settings.start_offset)
        settings.end_offset      = to_inches(result[1], settings.end_offset)
        settings.offset_lateral  = to_inches(result[2], settings.offset_lateral)
        settings.offset_vertical = to_inches(result[3], settings.offset_vertical)
        settings.extra_angle     = result[4].to_f
        settings.sanitize!
        on_change&.call
      end

      def jitter_dialog(settings, &on_change)
        prompts = %i[p_j_angle p_j_scale p_j_along p_j_side p_j_up p_seed]
                  .map { |key| PathCopyAdvanced.t(key) }
        defaults = [
          settings.jitter_angle.to_s,
          (settings.jitter_scale * 100.0).round(1).to_s,
          length(settings.jitter_along),
          length(settings.jitter_lateral),
          length(settings.jitter_vertical),
          settings.seed.to_s
        ]
        result = UI.inputbox(prompts, defaults, PathCopyAdvanced.t(:dlg_jitter))
        return unless result

        settings.jitter_angle    = result[0].to_f
        settings.jitter_scale    = result[1].to_f / 100.0
        settings.jitter_along    = to_inches(result[2], settings.jitter_along)
        settings.jitter_lateral  = to_inches(result[3], settings.jitter_lateral)
        settings.jitter_vertical = to_inches(result[4], settings.jitter_vertical)
        settings.seed            = result[5].to_i
        settings.jitter = true
        settings.sanitize!
        on_change&.call
      end

      def rail_dialog(settings, &on_change)
        prompts = %i[p_rail_width p_rail_height p_rail_extend p_rail_rise]
                  .map { |key| PathCopyAdvanced.t(key) }
        defaults = [length(settings.rail_width), length(settings.rail_height),
                    length(settings.rail_extend), length(settings.rail_rise)]
        result = UI.inputbox(prompts, defaults, PathCopyAdvanced.t(:dlg_rail))
        return unless result

        settings.rail_width  = to_inches(result[0], settings.rail_width)
        settings.rail_height = to_inches(result[1], settings.rail_height)
        settings.rail_extend = to_inches(result[2], settings.rail_extend)
        settings.rail_rise = to_inches(result[3], settings.rail_rise)
        settings.rail = true
        settings.sanitize!
        on_change&.call
      end

      def tag_dialog(settings, &on_change)
        result = UI.inputbox(
          [PathCopyAdvanced.t(:p_tag)],
          [settings.tag_name],
          PathCopyAdvanced.t(:dlg_tag)
        )
        return unless result

        settings.tag_name = result[0].to_s
        settings.sanitize!
        on_change&.call
      end

      def length(inches)
        Sketchup.format_length(inches.to_f)
      end

      def to_inches(text, fallback)
        value = text.to_s.strip
        return 0.0 if value.empty?

        value.to_l.to_f
      rescue ArgumentError
        UI.beep
        fallback.to_f
      end
    end
  end
end
