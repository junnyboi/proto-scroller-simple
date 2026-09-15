# In-game Chinese font coverage

ManusCC0 Regular, Medium and Bold remain the primary fonts. Their shared fallback is the complete, unsubsetted Noto Sans CJK SC Regular face at `assets/fonts/NotoSansCJKsc-Regular.otf`. It contains 44,810 Unicode codepoints and 65,535 glyphs, including simplified/traditional Chinese and many personal-name characters. Full upstream coverage does not mean every Unicode CJK extension is present.

The full font and its SIL Open Font License are bundled with the game. Operating-system fallback is disabled on this resource, so missing glyphs cannot be hidden by fonts installed on the developer's computer. The small Web loader fonts are independent and unchanged.

Run `python3 tools/sync_cjk_font.py --check` to verify the complete font bytes, licensing, import setting and all three primary/fallback resource chains. To restore the font, pass `--source /path/to/NotoSansCJKsc-Regular.otf`; the tool rejects subsets and any source whose SHA-256 differs from `2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b`. Never reduce the in-game fallback to the localization corpus: player names are dynamic text.
