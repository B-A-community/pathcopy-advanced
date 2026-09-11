# frozen_string_literal: true

module BACommunity
  module PathCopyAdvanced
    # Creates the actual entities.
    #
    # Undo handling is the big departure from the original, which called
    # Sketchup.undo - the *application's* undo - from inside onUserText and so
    # could roll back the user's earlier work. Here the first run opens a normal
    # operation and every subsequent tweak opens a transparent one that merges
    # into it, so the whole interactive session collapses to a single undo step.
    module Copier
      module_function

      # @return [Array<Sketchup::Drawingelement>] the entities created
      def run(model, sources, transformations, settings, merge_with_previous: false)
        return [] if sources.empty? || transformations.empty?

        entities = model.active_entities
        model.start_operation(PLUGIN_NAME, true, false, merge_with_previous)

        begin
          created = transformations.each_with_index.map do |transformation, index|
            duplicate(entities, sources[index % sources.size], transformation)
          end
          created.compact!

          apply_tag(model, created, settings.tag_name)
          created = [wrap(entities, created, sources.first)] if settings.group_result && created.size > 1

          model.commit_operation
          created
        rescue StandardError
          model.abort_operation
          raise
        end
      end

      # Removes a previous batch. Used when the user retypes a value and the
      # preview needs to be rebuilt in place.
      def erase(model, entities, merge_with_previous: true)
        alive = Array(entities).select { |entity| entity.valid? }
        return if alive.empty?

        model.start_operation("#{PLUGIN_NAME} (update)", true, false, merge_with_previous)
        begin
          model.active_entities.erase_entities(alive)
          model.commit_operation
        rescue StandardError
          model.abort_operation
          raise
        end
      end

      def duplicate(entities, source, transformation)
        # Group is matched first on purpose: the branch must not depend on how
        # Group and ComponentInstance happen to sit in the class hierarchy.
        case source
        when Sketchup::Group
          # Group#copy keeps group semantics (independent on edit) while still
          # sharing the definition until one is modified.
          copy = source.copy
          copy.transformation = transformation
          carry_over(source, copy)
          copy
        when Sketchup::ComponentInstance
          copy = entities.add_instance(source.definition, transformation)
          carry_over(source, copy)
          copy
        end
      end

      # The original dropped material, tag and name on every copy.
      def carry_over(source, copy)
        copy.material = source.material if source.material
        copy.layer = source.layer
        copy.name = source.name unless source.name.to_s.empty?
        copy.casts_shadows = source.casts_shadows?
        copy.receives_shadows = source.receives_shadows?
        copy
      rescue StandardError
        copy
      end

      def apply_tag(model, created, tag_name)
        name = tag_name.to_s.strip
        return if name.empty?

        layer = model.layers[name] || model.layers.add(name)
        created.each { |entity| entity.layer = layer }
      end

      def wrap(entities, created, source)
        group = entities.add_group(created)
        label = source.respond_to?(:definition) ? source.definition.name : 'objects'
        group.name = "PathCopy - #{label}"
        group
      end
    end
  end
end
