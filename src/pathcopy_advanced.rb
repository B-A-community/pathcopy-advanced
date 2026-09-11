# frozen_string_literal: true
#
# PathCopy Advanced - loader / extension manifest.
#
# A ground-up reimplementation of the "copy along a path" idea.
# Not derived from Smustard's PathCopy; see AUDIT.md for why.

require 'sketchup.rb'
require 'extensions.rb'

module BACommunity
  module PathCopyAdvanced
    ROOT_PATH   = File.dirname(File.expand_path(__FILE__)).freeze
    PLUGIN_PATH = File.join(ROOT_PATH, 'pathcopy_advanced').freeze
  end
end

# PLUGIN_NAME and VERSION live with the rest of the constants, so nothing below
# this directory depends on the loader having run first.
require File.join(BACommunity::PathCopyAdvanced::PLUGIN_PATH, 'constants')

module BACommunity
  module PathCopyAdvanced
    unless defined?(@loaded)
      @loaded = true

      extension = SketchupExtension.new(PLUGIN_NAME, File.join(PLUGIN_PATH, 'main.rb'))
      extension.version     = VERSION
      extension.creator     = 'B&A community'
      extension.copyright   = "2026 B&A community"
      extension.description =
        'Copy groups and components along paths: multi-edge paths without welding, ' \
        'spacing / count / fit distribution, true 3D orientation, live preview.'

      Sketchup.register_extension(extension, true)
    end
  end
end
