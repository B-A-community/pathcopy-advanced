# frozen_string_literal: true

module BACommunity
  module PathCopyAdvanced
    # Tool options, persisted across sessions via Sketchup.read_default.
    #
    # Lengths are stored as Floats in inches (SketchUp's internal unit);
    # angles in degrees; scale jitter as a fraction of 1.0.
    class Settings
      SECTION = 'BACommunityPathCopyAdvanced'

      DEFAULTS = {
        distribution:    :spacing,
        spacing:         48.0,
        count:           10,
        align:           :start,
        start_offset:    0.0,
        end_offset:      0.0,
        skip_seam:       true,

        orientation:     :flat,
        anchor:          :origin,
        extra_angle:     0.0,
        offset_lateral:  0.0,
        offset_vertical: 0.0,
        alternate_flip:  false,
        facing:          :auto,
        reverse_path:    false,

        jitter:          false,
        jitter_angle:    0.0,
        jitter_scale:    0.0,
        jitter_lateral:  0.0,
        jitter_along:    0.0,
        jitter_vertical: 0.0,
        seed:            1,

        nudge_angle:     90.0,

        rail:            false,
        rail_align:      :center,
        rail_width:      50.0 / 25.4,
        rail_height:     50.0 / 25.4,
        rail_shape:      :rect,
        rail_extend:     0.0,
        rail_rise:       0.0,

        group_result:    false,
        tag_name:        '',
        show_panel:      true
      }.freeze

      SYMBOL_KEYS = %i[distribution align orientation anchor facing rail_align rail_shape].freeze

      DEFAULTS.each_key { |key| attr_accessor key }

      def initialize
        DEFAULTS.each { |key, value| instance_variable_set("@#{key}", value) }
      end

      def self.load
        settings = new
        DEFAULTS.each do |key, fallback|
          stored = Sketchup.read_default(SECTION, key.to_s, nil)
          next if stored.nil?

          value = SYMBOL_KEYS.include?(key) ? stored.to_s.to_sym : stored
          settings.send("#{key}=", value)
        end
        settings.sanitize!
        settings
      end

      def save
        DEFAULTS.each_key do |key|
          value = send(key)
          value = value.to_s if value.is_a?(Symbol)
          Sketchup.write_default(SECTION, key.to_s, value)
        end
        self
      end

      # Clamps everything into a range that cannot hang or crash the tool.
      # The original happily accepted a negative spacing and a spacing of zero.
      def sanitize!
        @distribution = :spacing unless DISTRIBUTION_MODES.include?(@distribution)
        @orientation  = :flat    unless ORIENTATION_MODES.include?(@orientation)
        @align        = :start   unless ALIGN_MODES.include?(@align)
        @anchor       = :origin  unless ANCHOR_MODES.include?(@anchor)
        @facing       = :auto    unless FACING_MODES.include?(@facing)
        @rail_shape   = :rect    unless RAIL_SHAPES.include?(@rail_shape)
        @rail_align   = :center  unless RAIL_ALIGN_MODES.include?(@rail_align)

        @rail_width  = DEFAULTS[:rail_width]  unless @rail_width.to_f > TOLERANCE
        @rail_height = DEFAULTS[:rail_height] unless @rail_height.to_f > TOLERANCE
        @rail_extend = [@rail_extend.to_f, 0.0].max
        @rail_rise = @rail_rise.to_f
        @nudge_angle = @nudge_angle.to_f
        @nudge_angle = DEFAULTS[:nudge_angle] if @nudge_angle.abs < TOLERANCE

        @spacing = DEFAULTS[:spacing] unless @spacing.to_f > TOLERANCE
        @count   = @count.to_i.clamp(1, MAX_COPIES)

        @start_offset = [@start_offset.to_f, 0.0].max
        @end_offset   = [@end_offset.to_f, 0.0].max

        @extra_angle     = @extra_angle.to_f
        @offset_lateral  = @offset_lateral.to_f
        @offset_vertical = @offset_vertical.to_f

        @jitter_angle    = @jitter_angle.to_f.abs
        @jitter_scale    = @jitter_scale.to_f.abs.clamp(0.0, 0.95)
        @jitter_lateral  = @jitter_lateral.to_f.abs
        @jitter_along    = @jitter_along.to_f.abs
        @jitter_vertical = @jitter_vertical.to_f.abs
        @seed            = @seed.to_i

        @tag_name = @tag_name.to_s
        self
      end

      def cycle_distribution!(step = 1)
        @distribution = cycle(DISTRIBUTION_MODES, @distribution, step)
      end

      def cycle_orientation!(step = 1)
        @orientation = cycle(ORIENTATION_MODES, @orientation, step)
      end

      def cycle_align!(step = 1)
        @align = cycle(ALIGN_MODES, @align, step)
      end

      def cycle_anchor!(step = 1)
        @anchor = cycle(ANCHOR_MODES, @anchor, step)
      end

      def cycle_facing!(step = 1)
        @facing = cycle(FACING_MODES, @facing, step)
      end

      # One-line summary for the status bar.
      def summary
        parts = [DISTRIBUTION_LABELS[@distribution]]
        parts << case @distribution
                 when :count    then @count.to_s
                 when :vertices then '—'
                 else                Sketchup.format_length(@spacing)
                 end
        parts << ORIENTATION_LABELS[@orientation]
        parts << ALIGN_LABELS[@align] if @distribution == :spacing
        parts << FACING_LABELS[@facing] unless @facing == :auto
        parts << 'путь развёрнут' if @reverse_path
        parts << 'разброс' if @jitter
        parts << 'поручень' if @rail
        parts.join(' | ')
      end

      private

      def cycle(list, current, step)
        index = list.index(current) || 0
        list[(index + step) % list.size]
      end
    end
  end
end
