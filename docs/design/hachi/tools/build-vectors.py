from pathlib import Path
import argparse
import copy
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
NS = "{http://www.w3.org/2000/svg}"
ET.register_namespace("", NS[1:-1])


def canvas(size, label):
    return ET.Element(NS + "svg", {"width": str(size), "height": str(size),
                                   "viewBox": f"0 0 {size} {size}",
                                   "fill": "none", "role": "img", "aria-label": label})


def save(path, node):
    path.write_text(ET.tostring(node, encoding="unicode") + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("traces", type=Path)
    args = parser.parse_args()
    portrait = canvas(1254, "Quiet Balance C, four-tone vector trace of the approved sketch")
    for name, color in (("silhouette", "#FFFFFF"), ("light", "#C9C9C9"),
                        ("mid", "#707070"), ("ink", "#181818")):
        source = ET.parse(args.traces / f"{name}.svg").getroot()
        for group in source.findall(NS + "g"):
            group.set("fill", color)
            portrait.append(copy.deepcopy(group))
    save(ASSETS / "hachi-c.svg", portrait)

    layers = ASSETS / "icon-layers"
    layers.mkdir(exist_ok=True)
    background = canvas(1024, "Background color reference; set natively in Icon Composer")
    ET.SubElement(background, NS + "rect", {"width": "1024", "height": "1024", "fill": "#17201F"})
    save(layers / "00-background.svg", background)

    dog = canvas(1024, "Hachi foreground layer, transparent full canvas")
    placement = ET.SubElement(dog, NS + "g", {"transform": "translate(248 240) scale(0.42105263157894735)"})
    for group in portrait:
        placement.append(copy.deepcopy(group))
    save(layers / "01-hachi.svg", dog)

    for side, x in (("left", 120), ("right", 704)):
        panel = canvas(1024, f"Shoji {side} panel foreground layer")
        ET.SubElement(panel, NS + "rect", {"x": str(x), "y": "160", "width": "200", "height": "704", "rx": "16", "fill": "#D9DBD1"})
        ET.SubElement(panel, NS + "path", {"d": f"M{x+8} 392h184M{x+8} 624h184", "stroke": "#8F9A95", "stroke-width": "11.2", "stroke-linecap": "round"})
        save(layers / f"0{2 if side == 'left' else 3}-shoji-{side}.svg", panel)

    rail = canvas(1024, "Shoji lower rail foreground layer")
    ET.SubElement(rail, NS + "path", {"d": "M320 744h384", "stroke": "#E9E6DD", "stroke-width": "16", "stroke-linecap": "round"})
    save(layers / "04-shoji-rail.svg", rail)

    composition = {
        "purpose": "Layer manifest, not a native Icon Composer document",
        "canvas": {"width": 1024, "height": 1024},
        "background": {"color": "#17201F", "reference": "00-background.svg", "instruction": "Set the native Icon Composer background fill; do not import a second opaque background foreground."},
        "foregroundBackToFront": ["01-hachi.svg", "02-shoji-left.svg", "03-shoji-right.svg", "04-shoji-rail.svg"],
        "instructions": ["Retain full-canvas alignment and source colors.", "Hachi stays opaque and matte; no blur, transparency or material distortion on the face.", "Adjust any restrained panel glass material natively in Icon Composer.", "Do not bake in a corner mask, shadow, glow or lighting.", "Check macOS appearances and 16 pt legibility in Icon Composer before accepting the native document."]
    }
    (layers / "composition.json").write_text(json.dumps(composition, indent=2) + "\n")
    print("Exported vector portrait, five aligned layer references and composition manifest.")


if __name__ == "__main__":
    main()
