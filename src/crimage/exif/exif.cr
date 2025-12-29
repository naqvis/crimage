# EXIF (Exchangeable Image File Format) metadata parser.
#
# Supports reading EXIF metadata from JPEG, TIFF, and WebP images.
# EXIF data uses TIFF structure internally.
#
# ## Supported Tags
# - Orientation (auto-rotation)
# - DateTime, DateTimeOriginal, DateTimeDigitized
# - Make, Model (camera info)
# - GPS coordinates
# - Image dimensions
# - Software, Artist, Copyright
#
# ## Example
# ```
# exif = CrImage::EXIF.read("photo.jpg")
# puts exif.orientation # => 6 (rotate 90° CW)
# puts exif.date_time   # => 2024-01-15 10:30:00
# puts exif.camera      # => "iPhone 15 Pro"
# ```
module CrImage::EXIF
  # EXIF signature in JPEG APP1 segment
  EXIF_SIGNATURE = "Exif\x00\x00".to_slice

  # TIFF byte order markers
  LITTLE_ENDIAN = "II".to_slice
  BIG_ENDIAN    = "MM".to_slice

  # TIFF magic number
  TIFF_MAGIC = 42_u16

  # IFD entry size in bytes
  IFD_ENTRY_SIZE = 12

  # Standard EXIF tags
  enum Tag : UInt16
    # IFD0 (main image) tags
    ImageWidth        = 0x0100
    ImageLength       = 0x0101
    BitsPerSample     = 0x0102
    Compression       = 0x0103
    PhotometricInterp = 0x0106
    ImageDescription  = 0x010E
    Make              = 0x010F
    Model             = 0x0110
    Orientation       = 0x0112
    SamplesPerPixel   = 0x0115
    XResolution       = 0x011A
    YResolution       = 0x011B
    ResolutionUnit    = 0x0128
    Software          = 0x0131
    DateTime          = 0x0132
    Artist            = 0x013B
    WhitePoint        = 0x013E
    Copyright         = 0x8298

    # Pointers to sub-IFDs
    ExifIFDPointer = 0x8769
    GPSInfoPointer = 0x8825

    # EXIF sub-IFD tags
    ExposureTime          = 0x829A
    FNumber               = 0x829D
    ExposureProgram       = 0x8822
    ISOSpeedRatings       = 0x8827
    ExifVersion           = 0x9000
    DateTimeOriginal      = 0x9003
    DateTimeDigitized     = 0x9004
    ComponentsConfig      = 0x9101
    ShutterSpeedValue     = 0x9201
    ApertureValue         = 0x9202
    BrightnessValue       = 0x9203
    ExposureBiasValue     = 0x9204
    MaxApertureValue      = 0x9205
    MeteringMode          = 0x9207
    LightSource           = 0x9208
    Flash                 = 0x9209
    FocalLength           = 0x920A
    MakerNote             = 0x927C
    UserComment           = 0x9286
    SubsecTime            = 0x9290
    SubsecTimeOriginal    = 0x9291
    SubsecTimeDigitized   = 0x9292
    FlashpixVersion       = 0xA000
    ColorSpace            = 0xA001
    PixelXDimension       = 0xA002
    PixelYDimension       = 0xA003
    FocalPlaneXResolution = 0xA20E
    FocalPlaneYResolution = 0xA20F
    FocalPlaneResUnit     = 0xA210
    SensingMethod         = 0xA217
    FileSource            = 0xA300
    SceneType             = 0xA301
    CustomRendered        = 0xA401
    ExposureMode          = 0xA402
    WhiteBalance          = 0xA403
    DigitalZoomRatio      = 0xA404
    FocalLengthIn35mmFilm = 0xA405
    SceneCaptureType      = 0xA406
    GainControl           = 0xA407
    Contrast              = 0xA408
    Saturation            = 0xA409
    Sharpness             = 0xA40A
    LensSpecification     = 0xA432
    LensMake              = 0xA433
    LensModel             = 0xA434

    # GPS tags
    GPSVersionID     = 0x0000
    GPSLatitudeRef   = 0x0001
    GPSLatitude      = 0x0002
    GPSLongitudeRef  = 0x0003
    GPSLongitude     = 0x0004
    GPSAltitudeRef   = 0x0005
    GPSAltitude      = 0x0006
    GPSTimeStamp     = 0x0007
    GPSSatellites    = 0x0008
    GPSStatus        = 0x0009
    GPSMeasureMode   = 0x000A
    GPSDOP           = 0x000B
    GPSSpeedRef      = 0x000C
    GPSSpeed         = 0x000D
    GPSTrackRef      = 0x000E
    GPSTrack         = 0x000F
    GPSImgDirectRef  = 0x0010
    GPSImgDirection  = 0x0011
    GPSMapDatum      = 0x0012
    GPSDestLatRef    = 0x0013
    GPSDestLatitude  = 0x0014
    GPSDestLongRef   = 0x0015
    GPSDestLongitude = 0x0016
    GPSDestBearRef   = 0x0017
    GPSDestBearing   = 0x0018
    GPSDestDistRef   = 0x0019
    GPSDestDistance  = 0x001A
    GPSProcessMethod = 0x001B
    GPSAreaInfo      = 0x001C
    GPSDateStamp     = 0x001D
    GPSDifferential  = 0x001E
  end

  # TIFF data types
  enum DataType : UInt16
    Byte      =  1 # 8-bit unsigned
    ASCII     =  2 # 8-bit with null terminator
    Short     =  3 # 16-bit unsigned
    Long      =  4 # 32-bit unsigned
    Rational  =  5 # Two 32-bit unsigned (numerator/denominator)
    SByte     =  6 # 8-bit signed
    Undefined =  7 # 8-bit
    SShort    =  8 # 16-bit signed
    SLong     =  9 # 32-bit signed
    SRational = 10 # Two 32-bit signed
    Float     = 11 # 32-bit float
    Double    = 12 # 64-bit float
  end

  # Size in bytes for each data type
  DATA_TYPE_SIZES = {
    DataType::Byte      => 1,
    DataType::ASCII     => 1,
    DataType::Short     => 2,
    DataType::Long      => 4,
    DataType::Rational  => 8,
    DataType::SByte     => 1,
    DataType::Undefined => 1,
    DataType::SShort    => 2,
    DataType::SLong     => 4,
    DataType::SRational => 8,
    DataType::Float     => 4,
    DataType::Double    => 8,
  }

  # Image orientation values
  enum Orientation : UInt16
    Normal         = 1 # No transformation needed
    FlipHorizontal = 2 # Mirror horizontally
    Rotate180      = 3 # Rotate 180°
    FlipVertical   = 4 # Mirror vertically
    Transpose      = 5 # Mirror horizontal + rotate 270° CW
    Rotate90CW     = 6 # Rotate 90° clockwise
    Transverse     = 7 # Mirror horizontal + rotate 90° CW
    Rotate270CW    = 8 # Rotate 270° clockwise (90° CCW)
  end

  class FormatError < CrImage::FormatError
    def initialize(message : String = "Invalid EXIF data")
      super(message)
    end
  end
end

require "./data"
require "./reader"
