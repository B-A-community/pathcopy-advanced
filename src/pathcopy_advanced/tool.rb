# frozen_string_literal: true

module BACommunity
  module PathCopyAdvanced
    # The interactive tool.
    #
    # Three stages: pick a path, pick an object, then keep tweaking. Tweaks
    # rebuild the copies in place inside a transparent operation, so the entire
    # session collapses to a single undo step and the application-level undo is
    # never touched.
    class Tool
      BOX_EDGES = [
        [0, 1], [1, 3], [3, 2], [2, 0],
        [4, 5], [5, 7], [7, 6], [6, 4],
        [0, 4], [1, 5], [2, 6], [3, 7]
      ].freeze

      def initialize(settings = nil)
        @settings = settings || PathCopyAdvanced.settings
        reset_all
      end

      # --- tool lifecycle ------------------------------------------------

      def activate
        @cursor ||= Icons.cursor('pca_cursor', 4, 4)
        adopt_selection
        Panel.show(@settings) if @settings.show_panel
        Panel.attach(self, @settings)
        refresh
      end

      def deactivate(view)
        @settings.save
        Panel.detach(self)
        Sketchup.set_status_text('', SB_VCB_LABEL)
        Sketchup.set_status_text('', SB_VCB_VALUE)
        view.invalidate if view
      end

      # --- panel hooks ---------------------------------------------------

      # The panel changed a value: rebuild whatever is placed and redraw.
      def settings_changed
        apply
      end

      def panel_status
        case @state
        when :path   then PathCopyAdvanced.t(:ps_pick_path)
        when :source then PathCopyAdvanced.t(:ps_pick_source, preview_count)
        else
          spun = @manual_spin.empty? ? '' : PathCopyAdvanced.t(:ps_nudged, @manual_spin.size)
          PathCopyAdvanced.t(:ps_placed, @created.size, spun, @settings.nudge_angle.round)
        end
      end

      # Панель гасит настройки, которым нечего делать на текущем пути.
      # Доворот отдельной копии кликом переживает перестройку: он привязан к
      # номеру копии на пути, а не к самой сущности, которую мы пересоздаём.
      def nudge(index, back)
        step = @settings.nudge_angle.to_f
        step = -step if back
        @manual_spin[index] = ((@manual_spin[index] || 0.0) + step) % 360.0
        @manual_spin.delete(index) if @manual_spin[index].abs < TOLERANCE
        commit
      end

      def clear_nudges
        @manual_spin = {}
      end

      def panel_context
        paths = active_paths
        { has_path: !paths.empty?, closed: !paths.empty? && paths.all?(&:closed?),
          nudged: @manual_spin.size }
      end

      def suspend(view)
        view.invalidate
      end

      def resume(view)
        update_status
        view.invalidate
      end

      def onSetCursor
        UI.set_cursor(@cursor) if @cursor && @cursor != 0
      end

      def enableVCB?
        true
      end

      # --- input ---------------------------------------------------------

      def onMouseMove(_flags, x, y, view)
        helper = view.pick_helper
        helper.do_pick(x, y)

        if @state == :path
          hovered = hover_path(helper)
          if different_path?(hovered, @hover_path)
            @hover_path = hovered
            rebuild_preview
            view.invalidate
          end
        else
          hovered = pick_object(helper)
          if hovered != @hover_source
            @hover_source = hovered
            rebuild_preview
            view.invalidate
          end
        end
      end

      def onLButtonDown(flags, x, y, view)
        helper = view.pick_helper
        helper.do_pick(x, y)

        additive = modifier?(flags)

        case @state
        when :path
          choose_path(helper, additive: additive)
        when :source
          if additive && pick_object(helper).nil? && (extra = hover_path(helper))
            add_path(extra)
          else
            choose_source(helper, additive: additive)
          end
        else
          restart(helper, additive: additive, back: constrain?(flags))
        end

        refresh(view)
      end

      def onCancel(reason, view)
        case reason
        when 1 # the tool was re-selected: start over, leave placed copies alone
          reset_all
        when 2 # an undo already removed whatever we created
          @created = []
          @committed = false
          @state = @paths.empty? ? :path : :source
        else # escape
          step_back
        end
        refresh(view)
      end

      # Only keys SketchUp itself does not hand out as shortcuts: a bare letter
      # in a tool loses to whatever the user bound it to (R is the Rectangle
      # tool by default), so letters live in the panel instead. Key down, not
      # key up - macOS delivers Tab only on the way down.
      def onKeyDown(key, repeat, _flags, view)
        return false if repeat > 1

        handled = true
        case key
        when 9 # Tab
          @settings.cycle_distribution!
        when VK_UP
          @settings.cycle_orientation!
        when VK_DOWN
          @settings.cycle_orientation!(-1)
        when VK_RIGHT
          @settings.cycle_align!
        when VK_LEFT
          @settings.cycle_align!(-1)
        else
          handled = false
        end

        return false unless handled

        @settings.sanitize!
        apply(view)
        true
      end

      def onUserText(text, view)
        value = text.to_s.strip
        return if value.empty?

        count_match = value.match(/\A(\d+)\s*[xX*]\z/) || value.match(/\A[xX*]\s*(\d+)\z/)

        if count_match
          @settings.distribution = :count
          @settings.count = count_match[1].to_i
        elsif @settings.distribution == :count && value.match?(/\A\d+\z/)
          @settings.count = value.to_i
        elsif value == '0'
          @settings.distribution = :vertices
        else
          length = parse_length(value)
          return if length.nil?

          @settings.spacing = length
          @settings.distribution = :spacing unless %i[fit segments].include?(@settings.distribution)
        end

        @settings.sanitize!
        apply(view)
      rescue StandardError => error
        UI.beep
        warn("PathCopy Advanced: #{error.message}")
      end

      # --- drawing -------------------------------------------------------

      def getExtents
        box = Geom::BoundingBox.new
        active_paths.each { |path| box.add(path.bounds) }
        @preview.each { |entry| entry[:points].each { |point| box.add(point) } }
        box
      end

      def draw(view)
        draw_paths(view)
        draw_markers(view)
        draw_boxes(view)
        draw_rail(view)
      end

      # --- context menu --------------------------------------------------

      def getMenu(menu, _flags = 0, _x = 0, _y = 0, view = nil)
        Menus.build(menu, @settings) { apply(view) }
        true
      end

      # Своя папка на язык: SketchUp открывает index.html из неё как есть.
      def getInstructorContentDirectory
        File.join(__dir__, 'instructor', LANG)
      end

      private

      # --- state ---------------------------------------------------------

      def reset_all
        @state = :path
        @paths = []
        @sources = []
        @created = []
        @preview = []
        @hover_path = nil
        @hover_source = nil
        @committed = false
        @manual_spin = {}
        @placed_count = 0
      end


      def step_back
        if @created.any?
          Copier.erase(model, @created, merge_with_previous: true)
          @created = []
          @state = :source
        elsif @state == :source
          @paths = []
          @sources = []
          @state = :path
        else
          reset_all
        end
      end

      # In the :placed stage a click either swaps the object being copied or
      # starts a fresh run on a new path.
      def restart(helper, additive: false, back: false)
        # Клик по уже поставленной копии доворачивает именно её.
        placed = helper.best_picked
        if placed
          index = @created.index(placed)
          return nudge(index, back) if index && index < @placed_count
        end

        picked = pick_object(helper)
        if picked
          if additive
            @sources << picked unless @sources.include?(picked)
          else
            @sources = [picked]
          end
          commit
          return
        end

        path = hover_path(helper)
        return unless path

        # Modifier + an edge while placed: one more path, same objects.
        if additive
          add_path(path)
          commit
          return
        end

        @created = []
        @committed = false
        @paths = [path]
        @sources = []
        clear_nudges
        @state = :source
      end

      def model
        Sketchup.active_model
      end

      def active_paths
        paths = @paths.any? ? @paths : Array(@hover_path)
        @settings.reverse_path ? paths.map(&:reverse) : paths
      end

      def active_sources
        return @sources if @sources.any?

        Array(@hover_source)
      end

      # --- picking -------------------------------------------------------

      def adopt_selection
        selection = model.selection
        return if selection.empty?

        paths = PathBuilder.from_entities(selection.to_a)
        return if paths.empty?

        @paths = paths
        @state = :source
      end

      def hover_path(helper)
        edge = helper.picked_edge
        return PathBuilder.from_seed_edge(edge) if edge && in_context?(edge)

        face = helper.picked_face
        return PathBuilder.from_entities([face]).first if face && in_context?(face)

        nil
      end

      def different_path?(a, b)
        return false if a.nil? && b.nil?
        return true if a.nil? || b.nil?

        a.points.first != b.points.first || a.points.size != b.points.size
      end

      def choose_path(helper, additive: false)
        path = hover_path(helper)
        return UI.beep unless path

        if additive && @paths.any?
          add_path(path)
        else
          @paths = [path]
          @sources = []
          clear_nudges
        end
        @hover_path = nil
        @state = :source
        model.selection.clear
      end

      # Several separate runs of railing in one go: modifier-click each one.
      def add_path(path)
        duplicate = @paths.any? do |known|
          known.points.size == path.points.size && known.points.first == path.points.first
        end
        @paths << path unless duplicate
      end

      def pick_object(helper)
        picked = helper.best_picked
        return nil unless picked.is_a?(Sketchup::Group) || picked.is_a?(Sketchup::ComponentInstance)
        return nil if @created.include?(picked)

        picked
      end

      # Ctrl+click queues objects; a plain click adds the last one and places.
      # The queue is never replaced by the plain click - that is what makes
      # alternation reachable from the mouse at all.
      def choose_source(helper, additive: false)
        picked = pick_object(helper)
        return UI.beep unless picked

        @sources << picked unless @sources.include?(picked)
        return if additive

        commit
      end

      # Only geometry in the currently open editing context can be a path -
      # anything deeper carries a transformation we would have to guess at.
      def in_context?(entity)
        entity.parent == model.active_entities.parent
      rescue StandardError
        false
      end

      def modifier?(flags)
        return false unless defined?(COPY_MODIFIER_MASK)

        (flags & COPY_MODIFIER_MASK) != 0
      end

      def constrain?(flags)
        return false unless defined?(CONSTRAIN_MODIFIER_MASK)

        (flags & CONSTRAIN_MODIFIER_MASK) != 0
      end

      # --- work ----------------------------------------------------------

      def commit
        return if @paths.empty?
        return if active_sources.empty? && !@settings.rail

        Copier.erase(model, @created, merge_with_previous: true) if @created.any?

        transformations = all_transformations(active_sources)
        if transformations.empty? && !@settings.rail
          @created = []
          @state = :source
          return
        end

        @placed_count = transformations.size
        @created = Copier.run(
          model, active_sources, transformations, @settings,
          paths: active_paths, merge_with_previous: @committed
        )
        @committed = true
        @state = :placed
      rescue StandardError => error
        @created = []
        @state = :source
        UI.messagebox(PathCopyAdvanced.t(:err_place, error.message))
      end

      def all_transformations(sources)
        return [] if sources.empty?

        offset = 0
        active_paths.flat_map do |path|
          distances = Distribution.distances(path, @settings)
          placed = Placement.transformations(path, distances, @settings, sources,
                                             index_offset: offset, spins: @manual_spin)
          offset += placed.size
          placed
        end.first(MAX_COPIES)
      end

      # Redraw only. Called after clicks and after an undo, where the model is
      # already in the state the user asked for.
      def refresh(view = nil)
        rebuild_preview
        update_status
        Panel.push
        (view || model.active_view).invalidate
      end

      # Redraw and, if copies are already on the model, rebuild them to match
      # the changed options. Called from the value box, the keys and the menu.
      def apply(view = nil)
        commit if @state == :placed
        refresh(view)
      end

      def rebuild_preview
        sources = active_sources
        offset = 0
        @preview = active_paths.map do |path|
          distances = Distribution.distances(path, @settings)
          transformations =
            if sources.empty?
              []
            else
              Placement.transformations(path, distances, @settings, sources,
                                        index_offset: offset, spins: @manual_spin)
            end
          points =
            if transformations.any?
              transformations.map(&:origin)
            else
              distances.map { |distance| path.sample(distance).first }
            end
          entry = { path: path, transformations: transformations, points: points, offset: offset }
          offset += transformations.size
          entry
        end
      end

      def preview_count
        @preview.sum { |entry| entry[:points].size }
      end

      # --- status bar ----------------------------------------------------

      def update_status
        Sketchup.set_status_text(prompt, SB_PROMPT)
        Sketchup.set_status_text(vcb_label, SB_VCB_LABEL)
        Sketchup.set_status_text(vcb_value, SB_VCB_VALUE)
      end

      # Ctrl on Windows, Option on macOS - whatever COPY_MODIFIER_MASK maps to.
      MODIFIER = Sketchup.platform == :platform_osx ? 'Option' : 'Ctrl'
      def hints
        PathCopyAdvanced.t(:hints)
      end

      def prompt
        case @state
        when :path
          PathCopyAdvanced.t(:st_pick_path, MODIFIER, @settings.summary)
        when :source
          queued = @sources.empty? ? '' : PathCopyAdvanced.t(:st_queued_n, @sources.size)
          paths = @paths.size > 1 ? PathCopyAdvanced.t(:st_paths_n, @paths.size) : ''
          PathCopyAdvanced.t(:st_pick_source, MODIFIER) + paths + queued +
            PathCopyAdvanced.t(:st_places_n, preview_count) + hints
        else
          PathCopyAdvanced.t(:st_placed, @created.size, @settings.nudge_angle.round, hints)
        end
      end

      def vcb_label
        case @settings.distribution
        when :count    then PathCopyAdvanced.t(:vcb_copies)
        when :vertices then PathCopyAdvanced.t(:vcb_vertices)
        when :fit      then PathCopyAdvanced.t(:vcb_fit)
        when :segments then PathCopyAdvanced.t(:vcb_segments)
        else                PathCopyAdvanced.t(:vcb_spacing)
        end
      end

      def vcb_value
        case @settings.distribution
        when :count    then @settings.count.to_s
        when :vertices then preview_count.to_s
        else                Sketchup.format_length(@settings.spacing)
        end
      end

      def parse_length(text)
        text.to_l.to_f
      rescue ArgumentError
        UI.beep
        nil
      end

      # --- drawing helpers -----------------------------------------------

      def draw_paths(view)
        paths = active_paths
        return if paths.empty?

        view.line_stipple = ''
        view.line_width = 3
        view.drawing_color = COLOR_PATH
        paths.each { |path| view.draw(GL_LINE_STRIP, path.points) if path.points.size > 1 }
      end

      def draw_markers(view)
        segments = []
        @preview.each do |entry|
          entry[:points].each do |point|
            size = view.pixels_to_model(4, point)
            segments << point.offset(X_AXIS, -size) << point.offset(X_AXIS, size)
            segments << point.offset(Y_AXIS, -size) << point.offset(Y_AXIS, size)
            segments << point.offset(Z_AXIS, -size) << point.offset(Z_AXIS, size)
          end
        end
        return if segments.empty?

        view.line_width = 2
        view.drawing_color = COLOR_MARKER
        view.draw(GL_LINES, segments)
      end

      # Каркас поручня: контуры сечений и продольные рёбра профиля.
      def draw_rail(view)
        return unless @settings.rail

        segments = []
        active_paths.each do |path|
          rings = Railing.sections(path, @settings)
          next if rings.size < 2

          rings.each do |ring|
            ring.each_index { |i| segments << ring[i] << ring[(i + 1) % ring.size] }
          end
          limit = path.closed? ? rings.size : rings.size - 1
          (0...limit).each do |i|
            a = rings[i]
            b = rings[(i + 1) % rings.size]
            next unless a.size == b.size

            a.each_index { |k| segments << a[k] << b[k] }
          end
        end
        return if segments.empty?

        view.line_width = 1
        view.drawing_color = COLOR_PREVIEW
        view.draw(GL_LINES, segments)
      end

      def draw_boxes(view)
        sources = active_sources.select { |source| source.respond_to?(:definition) }
        return if sources.empty?

        corner_sets = sources.map do |source|
          bounds = source.definition.bounds
          bounds.empty? ? nil : (0..7).map { |index| bounds.corner(index) }
        end
        return if corner_sets.all?(&:nil?)

        total = @preview.sum { |entry| entry[:transformations].size }
        return if total.zero?

        stride = [(total.to_f / PREVIEW_BOX_LIMIT).ceil, 1].max
        segments = []

        @preview.each do |entry|
          entry[:transformations].each_with_index do |transformation, position|
            index = entry[:offset] + position
            next unless (index % stride).zero?

            corners = corner_sets[index % corner_sets.size]
            next if corners.nil?

            placed = corners.map { |corner| corner.transform(transformation) }
            BOX_EDGES.each { |a, b| segments << placed[a] << placed[b] }
          end
        end
        return if segments.empty?

        view.line_width = 1
        view.drawing_color = COLOR_PREVIEW
        view.draw(GL_LINES, segments)
      end
    end
  end
end
