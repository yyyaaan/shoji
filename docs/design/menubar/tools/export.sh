#!/bin/sh
set -eu
art_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
trace_work=$(mktemp -d /private/tmp/shoji-menubar.XXXXXX)
trap 'rm -rf "$trace_work"' EXIT HUP INT TERM
swift -module-cache-path /private/tmp/shoji-swift-cache "$art_root/../hachi/tools/trace-masks.swift" "$art_root/assets/dog-monochrome.png" "$trace_work"
potrace "$trace_work/ink.pbm" --svg --turdsize 8 --alphamax 1 --opttolerance 0.2 --output "$art_root/assets/hachi-menubar.svg"
potrace "$trace_work/ink.pbm" --backend pdf --turdsize 8 --alphamax 1 --opttolerance 0.2 --width 16pt --height 16pt --output "$art_root/assets/HachiMenuBar.imageset/hachi-menubar.pdf"
