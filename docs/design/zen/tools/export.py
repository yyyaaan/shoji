from pathlib import Path
import json
import subprocess
import tempfile
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
icons = []
for name in ('lantern', 'stones', 'bamboo', 'bonsai'):
    svg = ET.parse(root / 'assets' / f'{name}.svg').getroot()
    shapes = []
    for element in svg:
        attrs = dict(svg.attrib)
        attrs.update(element.attrib)
        shapes.append({'path': attrs['d'], 'fill': attrs.get('fill', 'none') != 'none',
                       'stroke': attrs.get('stroke', 'none') != 'none',
                       'width': float(attrs.get('stroke-width', 1)),
                       'strokeAlpha': float(attrs.get('stroke-opacity', 1))})
    icons.append({'name': 'Zen' + name.capitalize(), 'size': float(svg.attrib['viewBox'].split()[2]), 'shapes': shapes})
with tempfile.TemporaryDirectory(prefix='shoji-zen-', dir='/private/tmp') as work:
    geometry = Path(work) / 'geometry.json'
    geometry.write_text(json.dumps(icons))
    subprocess.run(['swift', '-module-cache-path', '/private/tmp/shoji-swift-cache',
                    str(root / 'tools/export.swift'), str(geometry), str(root.parents[2] / 'Sources/Shoji/UI/Artwork.xcassets')], check=True)
