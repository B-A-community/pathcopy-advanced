# frozen_string_literal: true
#
# Zero-dependency test runner. Run with:  ruby tests/run_tests.rb

require 'json'
require_relative 'sketchup_stub'

SRC = File.expand_path('../src/pathcopy_advanced', __dir__)
%w[lang constants path path_builder distribution placement railing copier settings icons panel menus tool]
  .each do |file|
  require File.join(SRC, file)
end

module Harness
  @tests = []
  @failures = []

  class << self
    attr_reader :tests, :failures

    def add(name, block)
      @tests << [name, block]
    end

    def run
      @tests.each do |name, block|
        block.call
        print '.'
      rescue StandardError, RuntimeError => error
        @failures << [name, error]
        print 'F'
      end
      puts
      puts

      @failures.each do |name, error|
        puts "FAIL: #{name}"
        puts "      #{error.class}: #{error.message}"
        location = error.backtrace&.find { |line| line.include?('tests') || line.include?('src') }
        puts "      #{location}" if location
        puts
      end

      puts "#{@tests.size} tests, #{@failures.size} failures"
      @failures.empty?
    end
  end
end

def test(name, &block)
  Harness.add(name, block)
end

def assert(condition, message = 'expected truthy')
  raise message.to_s unless condition
end

def assert_equal(expected, actual, message = nil)
  return if expected == actual

  raise "#{message || 'not equal'}: expected #{expected.inspect}, got #{actual.inspect}"
end

def assert_close(expected, actual, tolerance = 1.0e-6, message = nil)
  return if (expected.to_f - actual.to_f).abs <= tolerance

  raise "#{message || 'not close'}: expected #{expected}, got #{actual}"
end

def assert_point(expected, actual, tolerance = 1.0e-6)
  distance = actual.distance(Geom::Point3d.new(*expected))
  return if distance <= tolerance

  raise "expected point #{expected.inspect}, got #{actual.inspect} (off by #{distance})"
end

def assert_vector(expected, actual, tolerance = 1.0e-6)
  diff = [(actual.x - expected[0]).abs, (actual.y - expected[1]).abs, (actual.z - expected[2]).abs].max
  return if diff <= tolerance

  raise "expected vector #{expected.inspect}, got #{actual.inspect}"
end

def assert_raises(klass)
  yield
  raise "expected #{klass} to be raised"
rescue klass
  true
end

# --- shared builders --------------------------------------------------

include BACommunity::PathCopyAdvanced

def point(*coordinates)
  Geom::Point3d.new(*coordinates)
end

def build_path(points, closed: false)
  BACommunity::PathCopyAdvanced::Path.new(points.map { |p| point(*p) }, closed: closed)
end

# Builds edges from a list of [from, to] coordinate pairs, sharing vertices by
# position so that connectivity is real.
def build_edges(pairs)
  vertices = {}
  fetch = lambda do |coordinates|
    key = coordinates.map { |value| value.round(6) }
    vertices[key] ||= Sketchup::Vertex.new(point(*coordinates))
  end
  pairs.map { |from, to| Sketchup::Edge.new(fetch.call(from), fetch.call(to)) }
end

def settings_with(**overrides)
  settings = BACommunity::PathCopyAdvanced::Settings.new
  overrides.each { |key, value| settings.send("#{key}=", value) }
  settings
end

def instance_with(transformation: Geom::Transformation.new, bounds: nil, group: false)
  box = Geom::BoundingBox.new
  (bounds || [[0, 0, 0], [10, 4, 6]]).each { |corner| box.add(point(*corner)) }
  definition = Sketchup::ComponentDefinition.new('src', box)
  klass = group ? Sketchup::Group : Sketchup::ComponentInstance
  klass.new(definition, transformation)
end

Dir[File.join(__dir__, 'test_*.rb')].sort.each { |file| require file }

exit(Harness.run ? 0 : 1)
