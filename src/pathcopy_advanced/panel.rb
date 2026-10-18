# frozen_string_literal: true

require 'json'

module BACommunity
  module PathCopyAdvanced
    # The options panel: a non-modal HtmlDialog that stays open next to the
    # viewport. Every field applies immediately - while the tool is running the
    # copies rebuild in place, otherwise the value is just remembered.
    #
    # One instance for the session; the tool attaches on activate and detaches
    # on deactivate, so a change from the panel knows whether there is anything
    # to rebuild.
    module Panel
      HTML_FILE = File.join(__dir__, 'html', 'panel.html').freeze

      LENGTH_KEYS  = %i[spacing start_offset end_offset offset_lateral offset_vertical
                        jitter_along jitter_lateral jitter_vertical
                        rail_width rail_height rail_extend rail_rise].freeze
      INT_KEYS     = %i[count seed].freeze
      FLOAT_KEYS   = %i[extra_angle jitter_angle nudge_angle].freeze
      PERCENT_KEYS = %i[jitter_scale].freeze
      BOOL_KEYS    = %i[skip_seam reverse_path alternate_flip jitter group_result rail].freeze
      STRING_KEYS  = %i[tag_name].freeze

      OPTION_GROUPS = %i[distribution orientation align anchor facing rail_align rail_shape].freeze

      @dialog = nil
      @tool = nil
      @settings = nil

      class << self
        # Open (or raise) the panel for these settings.
        def show(settings)
          @settings = settings
          if @dialog&.visible?
            @dialog.bring_to_front
          else
            @dialog = build
            @dialog.show
          end
          push
        end

        def visible?
          !@dialog.nil? && @dialog.visible?
        end

        # The running tool, so panel changes rebuild its copies.
        def attach(tool, settings)
          @tool = tool
          @settings = settings
          push
        end

        def detach(tool)
          @tool = nil if @tool.equal?(tool)
          push
        end

        # Ruby -> panel. Called after any change made elsewhere (keys, value
        # box, menu) so the fields never lag behind the model.
        def push
          return unless visible? && @settings

          @dialog.execute_script("window.pca && pca.update(#{payload.to_json});")
        end

        private

        def build
          dialog = UI::HtmlDialog.new(
            dialog_title:    PLUGIN_NAME,
            preferences_key: 'BACommunity_PathCopyAdvanced_Panel',
            scrollable:      true,
            resizable:       true,
            width:           380,
            height:          700,
            min_width:       320,
            min_height:      420,
            style:           UI::HtmlDialog::STYLE_UTILITY
          )
          dialog.set_file(HTML_FILE)
          dialog.add_action_callback('ready') { |_ctx| push }
          dialog.add_action_callback('set') { |_ctx, key, value| assign(key, value) }
          dialog.add_action_callback('reset') { |_ctx| reset }
          dialog.add_action_callback('clear_nudges') do |_ctx|
            @tool&.clear_nudges
            @tool ? @tool.settings_changed : push
          end
          dialog.set_on_closed { @settings&.show_panel = false; @settings&.save }
          dialog
        end

        def payload
          s = @settings
          data = {}
          Settings::DEFAULTS.each_key do |key|
            value = s.send(key)
            data[key] =
              if LENGTH_KEYS.include?(key)   then Sketchup.format_length(value.to_f)
              elsif PERCENT_KEYS.include?(key) then (value.to_f * 100.0).round(1)
              elsif FLOAT_KEYS.include?(key)   then value.to_f.round(2)
              elsif value.is_a?(Symbol)        then value.to_s
              else value
              end
          end
          data[:options] = OPTION_GROUPS.each_with_object({}) do |group, hash|
            labels = PathCopyAdvanced.labels(group)
            hash[group] = MODE_LISTS[group].map { |mode| [mode.to_s, labels[mode]] }
          end
          data[:status] = @tool ? @tool.panel_status : PathCopyAdvanced.t(:ps_idle)
          context = @tool ? @tool.panel_context : { has_path: false, closed: false, nudged: 0 }
          data[:has_path] = context[:has_path]
          data[:path_closed] = context[:closed]
          data[:nudged] = context[:nudged].to_i
          data
        end

        def assign(key, value)
          key = key.to_s.to_sym
          return unless Settings::DEFAULTS.key?(key)

          parsed = parse(key, value.to_s)
          return push if parsed.nil?

          @settings.send("#{key}=", parsed)
          @settings.sanitize!
          @settings.save
          @tool ? @tool.settings_changed : push
        rescue StandardError => error
          warn("PathCopy Advanced panel: #{error.message}")
          push
        end

        def parse(key, text)
          if LENGTH_KEYS.include?(key)
            text.strip.empty? ? 0.0 : text.to_l.to_f
          elsif INT_KEYS.include?(key)     then text.to_i
          elsif FLOAT_KEYS.include?(key)   then text.to_f
          elsif PERCENT_KEYS.include?(key) then text.to_f / 100.0
          elsif BOOL_KEYS.include?(key)    then text == 'true'
          elsif STRING_KEYS.include?(key)  then text
          else text.to_sym
          end
        rescue ArgumentError
          UI.beep
          nil
        end

        def reset
          Settings::DEFAULTS.each { |key, value| @settings.send("#{key}=", value) unless key == :show_panel }
          @settings.sanitize!
          @settings.save
          @tool ? @tool.settings_changed : push
        end
      end
    end
  end
end
