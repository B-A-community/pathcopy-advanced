# frozen_string_literal: true
#
# A minimal stand-in for the parts of the SketchUp Ruby API that the geometry
# code touches, so Path / PathBuilder / Distribution / Placement can be run and
# asserted on from a plain Ruby interpreter.
#
# This is a test fixture, not a reimplementation - it covers exactly what the
# plugin calls and nothing more.

EPS = 1.0e-9

module Geom
  class Point3d
    attr_accessor :x, :y, :z

    def initialize(x = 0.0, y = 0.0, z = 0.0)
      if x.is_a?(Array)
        @x, @y, @z = x[0].to_f, x[1].to_f, x[2].to_f
      else
        @x = x.to_f
        @y = y.to_f
        @z = z.to_f
      end
    end

    def to_a
      [@x, @y, @z]
    end

    def clone
      Point3d.new(@x, @y, @z)
    end

    def distance(other)
      Math.sqrt((@x - other.x)**2 + (@y - other.y)**2 + (@z - other.z)**2)
    end

    def ==(other)
      other.is_a?(Point3d) && distance(other) < 1.0e-6
    end
    alias eql? ==

    def hash
      [@x.round(9), @y.round(9), @z.round(9)].hash
    end

    def -(other)
      return Vector3d.new(@x - other.x, @y - other.y, @z - other.z) if other.is_a?(Point3d)

      Point3d.new(@x - other.x, @y - other.y, @z - other.z)
    end

    def +(other)
      Point3d.new(@x + other.x, @y + other.y, @z + other.z)
    end

    def offset(vector, length = nil)
      scale = length.nil? ? 1.0 : length.to_f / vector.length
      Point3d.new(@x + vector.x * scale, @y + vector.y * scale, @z + vector.z * scale)
    end

    def transform(transformation)
      transformation.transform_point(self)
    end

    def inspect
      format('(%.4f, %.4f, %.4f)', @x, @y, @z)
    end
    alias to_s inspect
  end

  class Vector3d
    attr_accessor :x, :y, :z

    def initialize(x = 0.0, y = 0.0, z = 0.0)
      if x.is_a?(Array)
        @x, @y, @z = x[0].to_f, x[1].to_f, x[2].to_f
      else
        @x = x.to_f
        @y = y.to_f
        @z = z.to_f
      end
    end

    def to_a
      [@x, @y, @z]
    end

    def length
      Math.sqrt(@x * @x + @y * @y + @z * @z)
    end

    def length=(value)
      current = length
      raise ArgumentError, 'cannot set the length of a zero length vector' if current < EPS

      scale = value.to_f / current
      @x *= scale
      @y *= scale
      @z *= scale
      value
    end

    def valid?
      length > EPS
    end

    def normalize
      raise ArgumentError, 'zero length vector' if length < EPS

      Vector3d.new(@x / length, @y / length, @z / length)
    end

    def normalize!
      raise ArgumentError, 'zero length vector' if length < EPS

      len = length
      @x /= len
      @y /= len
      @z /= len
      self
    end

    def cross(other)
      Vector3d.new(
        @y * other.z - @z * other.y,
        @z * other.x - @x * other.z,
        @x * other.y - @y * other.x
      )
    end
    alias * cross

    def dot(other)
      @x * other.x + @y * other.y + @z * other.z
    end

    def parallel?(other)
      cross(other).length < 1.0e-9
    end

    def samedirection?(other)
      parallel?(other) && dot(other) > 0
    end

    def reverse
      Vector3d.new(-@x, -@y, -@z)
    end

    def transform(transformation)
      transformation.transform_vector(self)
    end

    def ==(other)
      other.is_a?(Vector3d) &&
        (@x - other.x).abs < 1.0e-6 && (@y - other.y).abs < 1.0e-6 && (@z - other.z).abs < 1.0e-6
    end

    def inspect
      format('<%.4f, %.4f, %.4f>', @x, @y, @z)
    end
    alias to_s inspect
  end

  # Column-major 4x4, matching SketchUp's Transformation#to_a layout:
  # translation lives at indices 12, 13, 14.
  class Transformation
    IDENTITY = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1].map(&:to_f).freeze

    attr_reader :m

    def initialize(argument = nil)
      @m =
        case argument
        when nil               then IDENTITY.dup
        when Array             then argument.map(&:to_f)
        when Transformation    then argument.m.dup
        when Point3d, Vector3d then Transformation.translation(argument).m
        else                        IDENTITY.dup
        end
    end

    def self.translation(offset)
      matrix = IDENTITY.dup
      matrix[12] = offset.x.to_f
      matrix[13] = offset.y.to_f
      matrix[14] = offset.z.to_f
      new(matrix)
    end

    def self.scaling(*args)
      sx, sy, sz = args.size == 1 ? [args[0], args[0], args[0]] : args
      matrix = IDENTITY.dup
      matrix[0] = sx.to_f
      matrix[5] = sy.to_f
      matrix[10] = sz.to_f
      new(matrix)
    end

    def self.axes(origin, x_axis, y_axis, z_axis)
      matrix = [
        x_axis.x, x_axis.y, x_axis.z, 0.0,
        y_axis.x, y_axis.y, y_axis.z, 0.0,
        z_axis.x, z_axis.y, z_axis.z, 0.0,
        origin.x, origin.y, origin.z, 1.0
      ]
      new(matrix)
    end

    def self.rotation(point, axis, angle)
      unit = axis.normalize
      c = Math.cos(angle)
      s = Math.sin(angle)
      t = 1.0 - c
      ux = unit.x
      uy = unit.y
      uz = unit.z

      rotation = [
        t * ux * ux + c,      t * ux * uy + s * uz, t * ux * uz - s * uy, 0.0,
        t * ux * uy - s * uz, t * uy * uy + c,      t * uy * uz + s * ux, 0.0,
        t * ux * uz + s * uy, t * uy * uz - s * ux, t * uz * uz + c,      0.0,
        0.0,                  0.0,                  0.0,                  1.0
      ]

      about_origin = new(rotation)
      return about_origin if point.x.abs < EPS && point.y.abs < EPS && point.z.abs < EPS

      translation(point) * about_origin * translation(Vector3d.new(-point.x, -point.y, -point.z))
    end

    def *(other)
      if other.is_a?(Transformation)
        product = Array.new(16, 0.0)
        4.times do |col|
          4.times do |row|
            sum = 0.0
            4.times { |k| sum += @m[k * 4 + row] * other.m[col * 4 + k] }
            product[col * 4 + row] = sum
          end
        end
        Transformation.new(product)
      elsif other.is_a?(Point3d)
        transform_point(other)
      else
        transform_vector(other)
      end
    end

    def transform_point(point)
      Point3d.new(
        @m[0] * point.x + @m[4] * point.y + @m[8] * point.z + @m[12],
        @m[1] * point.x + @m[5] * point.y + @m[9] * point.z + @m[13],
        @m[2] * point.x + @m[6] * point.y + @m[10] * point.z + @m[14]
      )
    end

    def transform_vector(vector)
      Vector3d.new(
        @m[0] * vector.x + @m[4] * vector.y + @m[8] * vector.z,
        @m[1] * vector.x + @m[5] * vector.y + @m[9] * vector.z,
        @m[2] * vector.x + @m[6] * vector.y + @m[10] * vector.z
      )
    end

    def origin
      Point3d.new(@m[12], @m[13], @m[14])
    end

    def xaxis
      Vector3d.new(@m[0], @m[1], @m[2])
    end

    def yaxis
      Vector3d.new(@m[4], @m[5], @m[6])
    end

    def zaxis
      Vector3d.new(@m[8], @m[9], @m[10])
    end

    # Affine inverse: invert the 3x3 block, then negate the translated origin.
    def inverse
      a = [
        [@m[0], @m[4], @m[8]],
        [@m[1], @m[5], @m[9]],
        [@m[2], @m[6], @m[10]]
      ]
      det = a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1]) -
            a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0]) +
            a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0])
      raise ArgumentError, 'singular transformation' if det.abs < 1.0e-12

      inv = Array.new(3) { Array.new(3, 0.0) }
      3.times do |i|
        3.times do |j|
          rows = [0, 1, 2] - [j]
          cols = [0, 1, 2] - [i]
          minor = a[rows[0]][cols[0]] * a[rows[1]][cols[1]] -
                  a[rows[0]][cols[1]] * a[rows[1]][cols[0]]
          inv[i][j] = ((i + j).even? ? minor : -minor) / det
        end
      end

      tx = -(inv[0][0] * @m[12] + inv[0][1] * @m[13] + inv[0][2] * @m[14])
      ty = -(inv[1][0] * @m[12] + inv[1][1] * @m[13] + inv[1][2] * @m[14])
      tz = -(inv[2][0] * @m[12] + inv[2][1] * @m[13] + inv[2][2] * @m[14])

      Transformation.new([
                           inv[0][0], inv[1][0], inv[2][0], 0.0,
                           inv[0][1], inv[1][1], inv[2][1], 0.0,
                           inv[0][2], inv[1][2], inv[2][2], 0.0,
                           tx, ty, tz, 1.0
                         ])
    end

    def to_a
      @m.dup
    end
  end

  class BoundingBox
    def initialize
      @min = nil
      @max = nil
    end

    def add(item)
      case item
      when BoundingBox
        return self if item.empty?

        add(item.min)
        add(item.max)
      when Array
        item.each { |element| add(element) }
      else
        if @min.nil?
          @min = item.clone
          @max = item.clone
        else
          @min = Point3d.new([@min.x, item.x].min, [@min.y, item.y].min, [@min.z, item.z].min)
          @max = Point3d.new([@max.x, item.x].max, [@max.y, item.y].max, [@max.z, item.z].max)
        end
      end
      self
    end

    def empty?
      @min.nil?
    end

    def min
      @min || Point3d.new
    end

    def max
      @max || Point3d.new
    end

    def center
      Point3d.new((min.x + max.x) / 2.0, (min.y + max.y) / 2.0, (min.z + max.z) / 2.0)
    end

    def corner(index)
      xs = index.odd? ? max.x : min.x
      ys = [2, 3, 6, 7].include?(index) ? max.y : min.y
      zs = index > 3 ? max.z : min.z
      Point3d.new(xs, ys, zs)
    end
  end
end

ORIGIN = Geom::Point3d.new(0, 0, 0)
X_AXIS = Geom::Vector3d.new(1, 0, 0)
Y_AXIS = Geom::Vector3d.new(0, 1, 0)
Z_AXIS = Geom::Vector3d.new(0, 0, 1)

class Numeric
  def degrees
    self * Math::PI / 180.0
  end

  def radians
    self * 180.0 / Math::PI
  end

  def inch
    to_f
  end

  def to_l
    to_f
  end
end

class String
  # Only what the tests feed in: a plain number with an optional unit suffix.
  def to_l
    text = strip
    match = text.match(/\A(-?[\d.]+)\s*(mm|cm|m|"|'|in|ft)?\z/)
    raise ArgumentError, "cannot convert #{inspect} to a Length" unless match

    value = Float(match[1])
    case match[2]
    when 'mm' then value / 25.4
    when 'cm' then value / 2.54
    when 'm'  then value / 0.0254
    when "'", 'ft' then value * 12.0
    else value
    end
  end
end

module Sketchup
  class Color
    attr_reader :red, :green, :blue

    def initialize(red = 0, green = 0, blue = 0)
      @red = red
      @green = green
      @blue = blue
    end
  end

  # --- entity stubs ---------------------------------------------------

  class Entity
    attr_accessor :parent
  end

  class Vertex < Entity
    attr_reader :position
    attr_accessor :edges

    def initialize(position)
      @position = position
      @edges = []
    end
  end

  class Edge < Entity
    attr_reader :start, :end
    attr_accessor :curve

    def initialize(start_vertex, end_vertex)
      @start = start_vertex
      @end = end_vertex
      @curve = nil
      start_vertex.edges << self
      end_vertex.edges << self
    end

    def other_vertex(vertex)
      vertex == @start ? @end : @start
    end

    def length
      @start.position.distance(@end.position)
    end
  end

  class Loop < Entity
    attr_reader :edges

    def initialize(edges)
      @edges = edges
    end
  end

  class Face < Entity
    attr_reader :outer_loop

    def initialize(edges)
      @outer_loop = Loop.new(edges)
    end
  end

  class Curve < Entity
    attr_reader :edges

    def initialize(edges)
      @edges = edges
    end
  end

  class ArcCurve < Curve; end

  class ComponentDefinition < Entity
    attr_accessor :name, :bounds

    def initialize(name = 'def', bounds = nil)
      @name = name
      @bounds = bounds || Geom::BoundingBox.new
    end
  end

  class Drawingelement < Entity
    attr_accessor :transformation, :definition, :material, :layer, :name

    def initialize(definition, transformation = Geom::Transformation.new)
      @definition = definition
      @transformation = transformation
      @name = ''
    end
  end

  class ComponentInstance < Drawingelement; end

  class Group < Drawingelement; end

  # --- module functions -----------------------------------------------

  @defaults = {}

  class << self
    def read_default(section, key, fallback = nil)
      (@defaults[section] || {}).fetch(key, fallback)
    end

    def write_default(section, key, value)
      (@defaults[section] ||= {})[key] = value
      true
    end

    def format_length(value)
      format('%.3f"', value.to_f)
    end

    def platform
      :platform_win
    end

    def version
      '24.0.0'
    end

    def require(path)
      Kernel.require(path.end_with?('.rb') ? path : "#{path}.rb")
    end

    def set_status_text(*); end

    def active_model
      raise NotImplementedError, 'no model in the test harness'
    end
  end
end

module UI
  def self.beep; end

  def self.messagebox(*); end

  def self.inputbox(*)
    false
  end

  def self.create_cursor(*)
    0
  end

  def self.set_cursor(*); end
end

# --- constants the tool code reads at runtime --------------------------

SB_PROMPT = 0
SB_VCB_LABEL = 1
SB_VCB_VALUE = 2

VK_UP = 38
VK_DOWN = 40
VK_LEFT = 37
VK_RIGHT = 39

GL_LINES = 1
GL_LINE_STRIP = 3

MF_ENABLED = 0
MF_CHECKED = 2
MF_UNCHECKED = 4

COPY_MODIFIER_MASK = 0x0008

# --- model-side stubs, for exercising Copier ---------------------------

module Sketchup
  class Layer
    attr_reader :name

    def initialize(name)
      @name = name
    end
  end

  class Layers
    def initialize
      @layers = {}
    end

    def [](name)
      @layers[name]
    end

    def add(name)
      @layers[name] ||= Layer.new(name)
    end
  end

  class Entities
    attr_reader :items

    def initialize
      @items = []
      @raise_on_add = false
    end

    attr_accessor :raise_on_add

    def add_instance(definition, transformation)
      raise ArgumentError, 'deliberate failure' if @raise_on_add

      instance = ComponentInstance.new(definition, transformation)
      instance.owner = self
      @items << instance
      instance
    end

    def add_group(entities)
      group = Group.new(ComponentDefinition.new('wrapper'), Geom::Transformation.new)
      group.owner = self
      group.contents = Array(entities)
      @items -= group.contents
      @items << group
      group
    end

    def erase_entities(entities)
      Array(entities).each do |entity|
        entity.erased = true
        @items.delete(entity)
      end
    end
  end

  class Model
    attr_reader :active_entities, :layers, :operations

    def initialize
      @active_entities = Entities.new
      @layers = Layers.new
      @operations = []
      @open = nil
    end

    def start_operation(name, disable_ui = false, next_transparent = false, transparent = false)
      raise 'operation already open' if @open

      @open = { name: name, disable_ui: disable_ui, transparent: transparent, outcome: nil }
      true
    end

    def commit_operation
      raise 'no operation open' unless @open

      @open[:outcome] = :committed
      @operations << @open
      @open = nil
      true
    end

    def abort_operation
      raise 'no operation open' unless @open

      @open[:outcome] = :aborted
      @operations << @open
      @open = nil
      true
    end
  end
end

class Sketchup::Drawingelement
  attr_accessor :owner, :contents, :erased

  def casts_shadows?
    @casts_shadows.nil? ? true : @casts_shadows
  end

  def receives_shadows?
    @receives_shadows.nil? ? true : @receives_shadows
  end

  attr_writer :casts_shadows, :receives_shadows

  def valid?
    !@erased
  end

  # Group#copy in the real API duplicates in place; the copy is then
  # repositioned by the caller.
  def copy
    duplicate = self.class.new(@definition, Geom::Transformation.new(@transformation))
    duplicate.owner = @owner
    @owner&.items&.<<(duplicate)
    duplicate
  end
end
