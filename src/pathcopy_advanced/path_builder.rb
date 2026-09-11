# frozen_string_literal: true

module BACommunity
  module PathCopyAdvanced
    # Turns a pile of SketchUp entities into ordered {Path} objects.
    #
    # This is the part the original plugin never had: it accepted exactly one
    # Edge or one Curve, which is why every tutorial started with "run Weld
    # first". Here an arbitrary set of edges is split into connected chains and
    # each chain is ordered end to end.
    module PathBuilder
      module_function

      # Build paths from an explicit set of entities (typically the selection).
      # Only the given edges are used - nothing is grown into neighbouring
      # geometry, because an explicit selection is an explicit intent.
      #
      # @return [Array<Path>]
      def from_entities(entities)
        edges = collect_edges(entities)
        return [] if edges.empty?

        build_chains(edges)
      end

      # Build a single path from one picked edge, growing through neighbouring
      # edges as far as the connectivity is unambiguous.
      #
      # Growth stops at any vertex that is not exactly degree-2, so the walk
      # never has to guess at a junction and never leaks into unrelated
      # geometry across a T.
      #
      # @return [Path, nil]
      def from_seed_edge(edge)
        return nil unless edge.is_a?(Sketchup::Edge)

        edges = grow(edge)
        build_chains(edges).first
      end

      # Faces contribute their outer loop; curves contribute all their edges.
      def collect_edges(entities)
        edges = []
        Array(entities).each do |entity|
          case entity
          when Sketchup::Edge
            edges << entity
          when Sketchup::Face
            edges.concat(entity.outer_loop.edges)
          when Sketchup::Curve, Sketchup::ArcCurve
            edges.concat(entity.edges)
          end
        end
        edges.uniq
      end

      # --- internals -----------------------------------------------------

      def grow(seed)
        collected = { seed => true }
        [seed.start, seed.end].each do |vertex|
          walk_outwards(seed, vertex, collected)
        end
        collected.keys
      end
      private_class_method :grow

      def walk_outwards(edge, vertex, collected)
        current_edge = edge
        current_vertex = vertex

        loop do
          neighbours = current_vertex.edges
          break unless neighbours.size == 2

          nxt = neighbours.find { |e| e != current_edge }
          break if nxt.nil? || collected[nxt]

          collected[nxt] = true
          current_edge = nxt
          current_vertex = nxt.other_vertex(current_vertex)
        end
      end
      private_class_method :walk_outwards

      # Split an unordered edge set into ordered, connected chains.
      def build_chains(edges)
        adjacency = Hash.new { |hash, key| hash[key] = [] }
        edges.each do |edge|
          adjacency[edge.start] << edge
          adjacency[edge.end] << edge
        end

        visited = {}
        paths = []

        # Open chains first, so that a chain with a free end is walked from
        # that end rather than from an arbitrary middle vertex.
        adjacency.each do |vertex, incident|
          next if incident.size == 2

          incident.each do |edge|
            next if visited[edge]

            paths << walk_chain(vertex, edge, adjacency, visited)
          end
        end

        # Whatever is left is a closed loop.
        edges.each do |edge|
          next if visited[edge]

          paths << walk_chain(edge.start, edge, adjacency, visited)
        end

        paths.compact.select(&:valid?)
      end
      private_class_method :build_chains

      def walk_chain(start_vertex, first_edge, adjacency, visited)
        points = [start_vertex.position]
        vertex = start_vertex
        edge = first_edge

        loop do
          visited[edge] = true
          vertex = edge.other_vertex(vertex)
          points << vertex.position

          break if vertex == start_vertex

          incident = adjacency[vertex]
          break unless incident.size == 2

          nxt = incident.find { |candidate| !visited[candidate] }
          break if nxt.nil?

          edge = nxt
        end

        closed = points.size > 2 && points.first == points.last
        Path.new(points, closed: closed)
      end
      private_class_method :walk_chain
    end
  end
end
