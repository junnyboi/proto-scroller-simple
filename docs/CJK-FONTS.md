# CC0 Simplified Chinese typography

ManusCC0 Regular, Medium and Bold remain the primary English/Latin fonts. `assets/fonts/ManusCC0SansCJKSC-Regular.woff2` supplies **ManusCC0 Sans CJK SC** as a shared Chinese glyph fallback. Both packs are CC0-1.0; attribution and delivered copyright/license notices are not required. The optional `ManusCC0-CJK-LICENSE.txt` records the dedication.

The runtime face is **965,224 bytes** with a **1,000,000-byte** maximum for both the font file and imported/exported font resource. Its fixed **6,547-codepoint** repertoire covers 6,500 common/general-use Simplified Chinese characters plus 47 existing UI/name/symbol extras. Rare names, full Han extensions, Traditional Chinese, other scripts and emoji are not guaranteed. Do not reduce runtime coverage to current UI text. System fallback is disabled.

Use `python3 tools/sync_cjk_font.py --check` to verify bytes, repertoire metadata and all three primary/fallback chains. Restore from the approved WOFF2 with `--source /path/to/ManusCC0SansCJKSC-Regular.woff2`. The canonical pack is `/Users/jun/Documents/Projects/Game Assets/ui/fonts/manus-cc0-sans-cjk-sc/`. Lightweight loader fonts derive from this same CC0 source and cover fixed loader text; they do not replace the runtime repertoire. The old Noto/Droid/Plushie sources are retired from this maintained project.
