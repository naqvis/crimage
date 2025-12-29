module CrImage::EXIF
  # EXIF data container and GPS coordinate representation.
  # GPS coordinates with latitude and longitude.
  struct GPSCoordinates
    getter latitude : Float64
    getter longitude : Float64
    getter altitude : Float64?

    def initialize(@latitude : Float64, @longitude : Float64, @altitude : Float64? = nil)
    end

    # Returns coordinates as a tuple (lat, lon).
    def to_tuple : {Float64, Float64}
      {@latitude, @longitude}
    end

    # Returns a Google Maps URL for these coordinates.
    def google_maps_url : String
      "https://www.google.com/maps?q=#{@latitude},#{@longitude}"
    end

    def to_s(io : IO) : Nil
      io << @latitude << ", " << @longitude
      if alt = @altitude
        io << " (alt: " << alt << "m)"
      end
    end
  end

  # Rational number representation (numerator/denominator).
  struct Rational
    getter numerator : UInt32
    getter denominator : UInt32

    def initialize(@numerator : UInt32, @denominator : UInt32)
    end

    def to_f : Float64
      return 0.0 if @denominator == 0
      @numerator.to_f64 / @denominator.to_f64
    end

    def to_s(io : IO) : Nil
      io << @numerator << "/" << @denominator
    end
  end

  # Signed rational number representation.
  struct SRational
    getter numerator : Int32
    getter denominator : Int32

    def initialize(@numerator : Int32, @denominator : Int32)
    end

    def to_f : Float64
      return 0.0 if @denominator == 0
      @numerator.to_f64 / @denominator.to_f64
    end

    def to_s(io : IO) : Nil
      io << @numerator << "/" << @denominator
    end
  end

  # Container for parsed EXIF metadata.
  #
  # Provides convenient access to common EXIF tags with proper typing.
  class Data
    # Raw tag values by tag ID
    getter tags : Hash(UInt16, TagValue)

    # EXIF sub-IFD tags
    getter exif_tags : Hash(UInt16, TagValue)

    # GPS sub-IFD tags
    getter gps_tags : Hash(UInt16, TagValue)

    def initialize
      @tags = {} of UInt16 => TagValue
      @exif_tags = {} of UInt16 => TagValue
      @gps_tags = {} of UInt16 => TagValue
    end

    # Image orientation (1-8). Returns 1 (normal) if not present.
    def orientation : Orientation
      if val = @tags[Tag::Orientation.value]?
        if u16 = val.as_u16
          Orientation.from_value?(u16) || Orientation::Normal
        else
          Orientation::Normal
        end
      else
        Orientation::Normal
      end
    end

    # Returns true if image needs rotation/flip based on orientation.
    def needs_transform? : Bool
      orientation != Orientation::Normal
    end

    # Camera manufacturer.
    def make : String?
      @tags[Tag::Make.value]?.try(&.as_string)
    end

    # Camera model.
    def model : String?
      @tags[Tag::Model.value]?.try(&.as_string)
    end

    # Combined camera make and model.
    def camera : String?
      m = make
      mod = model
      return nil if m.nil? && mod.nil?
      [m, mod].compact.join(" ")
    end

    # Software used to create/edit the image.
    def software : String?
      @tags[Tag::Software.value]?.try(&.as_string)
    end

    # Artist/photographer name.
    def artist : String?
      @tags[Tag::Artist.value]?.try(&.as_string)
    end

    # Copyright information.
    def copyright : String?
      @tags[Tag::Copyright.value]?.try(&.as_string)
    end

    # Image description.
    def description : String?
      @tags[Tag::ImageDescription.value]?.try(&.as_string)
    end

    # Date/time the image was last modified.
    def date_time : Time?
      parse_exif_datetime(@tags[Tag::DateTime.value]?.try(&.as_string))
    end

    # Date/time the original image was taken.
    def date_time_original : Time?
      parse_exif_datetime(@exif_tags[Tag::DateTimeOriginal.value]?.try(&.as_string))
    end

    # Date/time the image was digitized.
    def date_time_digitized : Time?
      parse_exif_datetime(@exif_tags[Tag::DateTimeDigitized.value]?.try(&.as_string))
    end

    # Best available date/time (original > digitized > modified).
    def taken_at : Time?
      date_time_original || date_time_digitized || date_time
    end

    # Image width in pixels (from EXIF, may differ from actual).
    def width : UInt32?
      @exif_tags[Tag::PixelXDimension.value]?.try(&.as_u32) ||
        @tags[Tag::ImageWidth.value]?.try(&.as_u32)
    end

    # Image height in pixels (from EXIF, may differ from actual).
    def height : UInt32?
      @exif_tags[Tag::PixelYDimension.value]?.try(&.as_u32) ||
        @tags[Tag::ImageLength.value]?.try(&.as_u32)
    end

    # Exposure time in seconds.
    def exposure_time : Rational?
      @exif_tags[Tag::ExposureTime.value]?.try(&.as_rational)
    end

    # F-number (aperture).
    def f_number : Float64?
      @exif_tags[Tag::FNumber.value]?.try(&.as_rational).try(&.to_f)
    end

    # ISO speed rating.
    def iso : UInt32?
      @exif_tags[Tag::ISOSpeedRatings.value]?.try(&.as_u32)
    end

    # Focal length in mm.
    def focal_length : Float64?
      @exif_tags[Tag::FocalLength.value]?.try(&.as_rational).try(&.to_f)
    end

    # Focal length equivalent in 35mm film.
    def focal_length_35mm : UInt32?
      @exif_tags[Tag::FocalLengthIn35mmFilm.value]?.try(&.as_u32)
    end

    # Flash fired?
    def flash_fired? : Bool?
      val = @exif_tags[Tag::Flash.value]?.try(&.as_u16)
      return nil if val.nil?
      (val & 0x01) != 0
    end

    # Lens model.
    def lens_model : String?
      @exif_tags[Tag::LensModel.value]?.try(&.as_string)
    end

    # Lens manufacturer.
    def lens_make : String?
      @exif_tags[Tag::LensMake.value]?.try(&.as_string)
    end

    # GPS coordinates if available.
    def gps : GPSCoordinates?
      return nil if @gps_tags.empty?

      lat = parse_gps_coordinate(
        @gps_tags[Tag::GPSLatitude.value]?,
        @gps_tags[Tag::GPSLatitudeRef.value]?
      )
      lon = parse_gps_coordinate(
        @gps_tags[Tag::GPSLongitude.value]?,
        @gps_tags[Tag::GPSLongitudeRef.value]?
      )

      return nil if lat.nil? || lon.nil?

      alt = parse_gps_altitude(
        @gps_tags[Tag::GPSAltitude.value]?,
        @gps_tags[Tag::GPSAltitudeRef.value]?
      )

      GPSCoordinates.new(lat, lon, alt)
    end

    # Returns true if EXIF data contains any tags.
    def empty? : Bool
      @tags.empty? && @exif_tags.empty? && @gps_tags.empty?
    end

    # Returns true if GPS data is present.
    def has_gps? : Bool
      !@gps_tags.empty? &&
        @gps_tags.has_key?(Tag::GPSLatitude.value) &&
        @gps_tags.has_key?(Tag::GPSLongitude.value)
    end

    private def parse_exif_datetime(str : String?) : Time?
      return nil if str.nil? || str.empty?
      # EXIF format: "YYYY:MM:DD HH:MM:SS"
      Time.parse(str, "%Y:%m:%d %H:%M:%S", Time::Location::UTC)
    rescue
      nil
    end

    private def parse_gps_coordinate(value : TagValue?, ref : TagValue?) : Float64?
      return nil if value.nil?

      rationals = value.as_rational_array
      return nil if rationals.nil? || rationals.size < 3

      degrees = rationals[0].to_f
      minutes = rationals[1].to_f
      seconds = rationals[2].to_f

      coord = degrees + minutes / 60.0 + seconds / 3600.0

      # Apply direction (S/W are negative)
      if r = ref.try(&.as_string)
        coord = -coord if r == "S" || r == "W"
      end

      coord
    end

    private def parse_gps_altitude(value : TagValue?, ref : TagValue?) : Float64?
      return nil if value.nil?

      alt = value.as_rational.try(&.to_f)
      return nil if alt.nil?

      # Ref 1 = below sea level
      if r = ref.try(&.as_u8)
        alt = -alt if r == 1
      end

      alt
    end
  end

  # Wrapper for tag values with type conversion helpers.
  class TagValue
    alias RawType = UInt8 | UInt16 | UInt32 | Int32 | String | Rational | SRational |
                    Array(UInt8) | Array(UInt16) | Array(UInt32) | Array(Rational)

    getter raw : RawType

    def initialize(@raw)
    end

    def as_u8 : UInt8?
      case v = @raw
      when UInt8  then v
      when UInt16 then v <= UInt8::MAX ? v.to_u8 : nil
      when UInt32 then v <= UInt8::MAX ? v.to_u8 : nil
      when Int32  then (v >= 0 && v <= UInt8::MAX) ? v.to_u8 : nil
      else             nil
      end
    end

    def as_u16 : UInt16?
      case v = @raw
      when UInt8  then v.to_u16
      when UInt16 then v
      when UInt32 then v.to_u16
      when Int32  then v.to_u16
      else             nil
      end
    end

    def as_u32 : UInt32?
      case v = @raw
      when UInt8  then v.to_u32
      when UInt16 then v.to_u32
      when UInt32 then v
      when Int32  then v.to_u32
      else             nil
      end
    end

    def as_i32 : Int32?
      case v = @raw
      when UInt8  then v.to_i32
      when UInt16 then v.to_i32
      when UInt32 then v.to_i32
      when Int32  then v
      else             nil
      end
    end

    def as_string : String?
      case v = @raw
      when String then v
      else             nil
      end
    end

    def as_rational : Rational?
      case v = @raw
      when Rational        then v
      when Array(Rational) then v.first?
      else                      nil
      end
    end

    def as_srational : SRational?
      case v = @raw
      when SRational then v
      else                nil
      end
    end

    def as_rational_array : Array(Rational)?
      case v = @raw
      when Array(Rational) then v
      when Rational        then [v]
      else                      nil
      end
    end

    def as_bytes : Array(UInt8)?
      case v = @raw
      when Array(UInt8) then v
      else                   nil
      end
    end
  end
end
