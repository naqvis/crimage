# Fonts Directory

This directory is for TrueType (.ttf) font files used by the examples.

## Font files are NOT included in the repository

Due to licensing and file size considerations, font files are not included. You need to download them separately.

## Recommended Open Source Fonts

### Option 1: Google Fonts (Easiest)

Download any font from https://fonts.google.com/

Popular choices:

- **Roboto**: https://fonts.google.com/specimen/Roboto
- **Open Sans**: https://fonts.google.com/specimen/Open+Sans
- **Noto Sans**: https://fonts.google.com/specimen/Noto+Sans

After downloading:

1. Extract the .ttf file
2. Place it in this `fonts/` directory
3. Use it in examples: `FreeType::TrueType.load("fonts/Roboto-Regular.ttf")`

### Option 2: Liberation Fonts

```bash
# On macOS with Homebrew
brew install --cask font-liberation

# On Ubuntu/Debian
sudo apt-get install fonts-liberation

# Or download from:
# https://github.com/liberationfonts/liberation-fonts/releases
```

### Option 3: DejaVu Fonts

```bash
# On macOS with Homebrew
brew install --cask font-dejavu

# On Ubuntu/Debian
sudo apt-get install fonts-dejavu

# Or download from:
# https://dejavu-fonts.github.io/
```

### Option 4: Use System Fonts

On macOS:

```crystal
FreeType::TrueType.load("/System/Library/Fonts/Helvetica.ttc")
```

On Linux:

```crystal
FreeType::TrueType.load("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
```

## Quick Start

1. Download Roboto from Google Fonts
2. Extract `Roboto-Regular.ttf` to this directory
3. Run the example:
   ```bash
   crystal run examples/draw_text.cr fonts/Roboto-Regular.ttf "Hello World"
   ```

## License Information

All recommended fonts are open source with permissive licenses:

- **SIL Open Font License**: Free for commercial and personal use
- **Apache License 2.0**: Free for commercial and personal use
- **Liberation Fonts**: GPL with font exception (can be embedded)

Always check the specific license file included with each font.
