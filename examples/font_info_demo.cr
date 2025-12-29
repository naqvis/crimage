require "../src/crimage"
require "../src/freetype"

# Font Information Demo
# Demonstrates font metadata extraction and character coverage checking

puts "Font Information Demo"
puts "=" * 60

# Check for font
font_path = "fonts/Roboto/static/Roboto-Regular.ttf"

unless File.exists?(font_path)
  puts "Font not found at #{font_path}"
  puts "Please install fonts. See fonts/README.md"
  exit 1
end

# Load font with metadata
puts "Loading font: #{font_path}"
ttf = FreeType::TrueType.load(font_path)
font = FreeType::Info.load(ttf)

puts ""
puts "Font Metadata:"
puts "-" * 60

# Basic information
puts "Family Name:      #{font.info.family_name}"
puts "Style Name:       #{font.info.style_name}"
puts "Full Name:        #{font.info.full_name}"
puts "Version:          #{font.info.version}"
puts "PostScript Name:  #{font.info.postscript_name}"

# Additional metadata
unless font.info.copyright.empty?
  puts ""
  puts "Copyright:        #{font.info.copyright[0...60]}..."
end

unless font.info.manufacturer.empty?
  puts "Manufacturer:     #{font.info.manufacturer}"
end

unless font.info.designer.empty?
  puts "Designer:         #{font.info.designer}"
end

puts ""
puts "Font Properties:"
puts "-" * 60
puts "Glyph Count:      #{font.glyph_count}"
puts "Has Kerning:      #{font.has_kerning? ? "Yes" : "No"}"
puts "Has Vertical:     #{font.has_vertical_metrics? ? "Yes" : "No"}"
puts "Variable Font:    #{font.is_variable? ? "Yes" : "No"}"

puts ""
puts "Character Coverage:"
puts "-" * 60

# Test basic ASCII
test_strings = [
  "Hello World",
  "0123456789",
  "!@#$%^&*()",
  "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
  "abcdefghijklmnopqrstuvwxyz",
]

test_strings.each do |text|
  has_all = font.has_chars?(text)
  status = has_all ? "✓" : "✗"
  puts "#{status} #{text[0...30]}"

  unless has_all
    missing = font.missing_chars(text)
    puts "  Missing: #{missing.join(", ")}"
  end
end

# Test extended characters
puts ""
puts "Extended Character Support:"
puts "-" * 60

extended_tests = [
  {'€', "Euro sign"},
  {'©', "Copyright symbol"},
  {'™', "Trademark symbol"},
  {'°', "Degree symbol"},
  {'±', "Plus-minus sign"},
  {'×', "Multiplication sign"},
  {'÷', "Division sign"},
  {'α', "Greek alpha"},
  {'β', "Greek beta"},
  {'→', "Right arrow"},
  {'♥', "Heart symbol"},
  {'★', "Star symbol"},
]

extended_tests.each do |(char, desc)|
  has_char = font.has_char?(char)
  status = has_char ? "✓" : "✗"
  puts "#{status} #{char} (#{desc})"
end

# Test Unicode ranges with coverage() method
puts ""
puts "Unicode Range Examples:"
puts "-" * 60

unicode_tests = [
  {"Latin", "ABCabc"},
  {"Numbers", "0123456789"},
  {"Punctuation", ".,;:!?"},
  {"Symbols", "+-=<>"},
  {"Accented", "àáâãäåæçèéêë"},
  {"Cyrillic", "АБВГДабвгд"},
  {"Greek", "ΑΒΓΔΕαβγδε"},
  {"Arabic", "ابتثج"},
  {"CJK", "你好世界"},
  {"Emoji", "😀🎉❤️"},
]

unicode_tests.each do |(name, sample)|
  coverage = font.coverage(sample)
  status = coverage == 100.0 ? "✓" : "✗"
  puts "#{status} #{name.ljust(15)} #{coverage.round(1)}% (#{sample[0...10]})"
end

# Show detected Unicode ranges
puts ""
puts "Detected Unicode Ranges:"
puts "-" * 60

ranges = font.unicode_ranges
ranges.each do |r|
  next if r[:coverage] == 0.0 # Skip unsupported ranges

  status = r[:coverage] >= 90.0 ? "✓" : "◐"
  puts "#{status} #{r[:name].ljust(25)} #{r[:coverage].round(1)}%"
end

puts ""
puts "=" * 60
puts "Font information extracted successfully!"
