#!/usr/bin/env python3
"""Compatibility entry point: install the full in-game CJK font, never a subset.

Small loader font generation remains owned by its separate loader pipeline.
"""
from sync_cjk_font import main

if __name__ == '__main__':
    main()
