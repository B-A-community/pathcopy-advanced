# frozen_string_literal: true

module BACommunity
  module PathCopyAdvanced
    # Resolves icon paths relative to this file, never via a hard-coded
    # "Plugins/..." string the way the original did.
    module Icons
      DIRECTORY = File.join(__dir__, 'icons').freeze

      module_function

      # SketchUp 2016+ takes SVG on Windows and PDF on macOS for crisp HiDPI
      # toolbars, and falls back to PNG everywhere else.
      def toolbar(basename)
        vector = Sketchup.platform == :platform_win ? "#{basename}.svg" : "#{basename}.pdf"
        candidate = File.join(DIRECTORY, vector)
        return candidate if Sketchup.version.to_i >= 16 && File.exist?(candidate)

        File.join(DIRECTORY, "#{basename}.png")
      end

      def cursor(basename, hot_x, hot_y)
        path = File.join(DIRECTORY, "#{basename}.png")
        return 0 unless File.exist?(path)

        UI.create_cursor(path, hot_x, hot_y)
      end
    end
  end
end
