require "../spec_helper"

module CrImage::Math::F64
  describe "F64 Vector Tests" do
    it "creates Vec2" do
      v = Vec2[1.0, 2.0]
      v.to_s.should contain("Vec2")
    end

    it "creates Vec3" do
      v = Vec3[1.0, 2.0, 3.0]
      v.to_s.should contain("Vec3")
    end

    it "creates Vec4" do
      v = Vec4[1.0, 2.0, 3.0, 4.0]
      v.to_s.should contain("Vec4")
    end

    it "raises error for wrong number of elements in Vec2" do
      expect_raises(Exception, /2 element/) do
        Vec2[1.0, 2.0, 3.0]
      end
    end

    it "raises error for wrong number of elements in Vec3" do
      expect_raises(Exception, /3 element/) do
        Vec3[1.0, 2.0]
      end
    end

    it "raises error for wrong number of elements in Vec4" do
      expect_raises(Exception, /4 element/) do
        Vec4[1.0, 2.0, 3.0]
      end
    end
  end

  describe "F64 Matrix Tests" do
    it "creates Mat3" do
      m = Mat3[1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]
      m.to_s.should contain("Mat3")
    end

    it "creates Mat4" do
      m = Mat4[
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
      ]
      m.to_s.should contain("Mat4")
    end

    it "raises error for wrong number of elements in Mat3" do
      expect_raises(Exception, /9 element/) do
        Mat3[1.0, 2.0, 3.0]
      end
    end

    it "raises error for wrong number of elements in Mat4" do
      expect_raises(Exception, /16 element/) do
        Mat4[1.0, 2.0, 3.0]
      end
    end
  end

  describe "F64 Affine Transform Tests" do
    it "creates Aff3" do
      a = Aff3[1.0, 0.0, 0.0, 0.0, 1.0, 0.0]
      a.to_s.should contain("Aff3")
    end

    it "creates Aff4" do
      a = Aff4[
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
      ]
      a.to_s.should contain("Aff4")
    end

    it "raises error for wrong number of elements in Aff3" do
      expect_raises(Exception, /6 element/) do
        Aff3[1.0, 2.0, 3.0]
      end
    end

    it "raises error for wrong number of elements in Aff4" do
      expect_raises(Exception, /12 element/) do
        Aff4[1.0, 2.0, 3.0]
      end
    end
  end
end
