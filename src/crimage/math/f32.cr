# CrImage::Math::F32 provides 32-bit floating-point vector and matrix types.
#
# Includes:
# - 2D, 3D, 4D vectors (Vec2, Vec3, Vec4)
# - 3x3 and 4x4 matrices (Mat3, Mat4)
# - 3x3 and 4x4 affine transformation matrices (Aff3, Aff4)
#
# All types use Float32 for memory efficiency in graphics operations.
module CrImage::Math::F32
  macro define_class(name, size, comment)
  # {{comment.split("\n").join("\n#").id}}
  struct {{name}}
  def self.[](*parts)
      raise "#{self.name} is {{size}} element vector" unless parts.size == {{size}}
      arr = Array(Float32).new({{size}})
    parts.each {|x| arr << x.to_f32 }
    new(arr)
  end

  private def initialize(@arr : Array(Float32))
  end

  def to_s(io : IO) : Nil
      io << "{{name}}[#{@arr.join(",")}]"
  end
  end
end

  define_class(Vec2, 2, "Vec2 is a 2-element vector")
  define_class(Vec3, 3, "Vec3 is a 3-element vector")
  define_class(Vec4, 4, "Vec4 is a 4-element vector")

  define_class(Mat3, 9, "Mat3 is a 3x3 matrix in row major order.\n\n m[3*r + c] is the element in the r'th row and c'th column.")
  define_class(Mat4, 16, "Mat4 is a 4x4 matrix in row major order.\n\n m[4*r + c] is the element in the r'th row and c'th column.")

  define_class(Aff3, 6, "Aff3 is a 3x3 affine transformation matrix in row major order, where the\nbottom row is implicitly [0 0 1].\n\n m[3*r + c] is the element in the r'th row and c'th column.")
  define_class(Aff4, 12, "Aff4 is a 4x4 affine transformation matrix in row major order, where the\nbottom row is implicitly [0 0 0 1].\n\n m[4*r + c] is the element in the r'th row and c'th column.")
end
