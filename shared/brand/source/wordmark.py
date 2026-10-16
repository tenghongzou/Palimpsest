"""Outline 'Palimpsest' from an OFL variable font into an SVG path."""
import sys, json
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen

def outline(font_path, axes, text='Palimpsest', tracking=0):
    f = TTFont(font_path)
    if 'fvar' in f:
        f = instantiateVariableFont(f, axes)
    gs = f.getGlyphSet(); cmap = f.getBestCmap(); upm = f['head'].unitsPerEm
    hmtx = f['hmtx']
    pen = SVGPathPen(gs); bpen = BoundsPen(gs)
    x = 0
    for ch in text:
        g = cmap[ord(ch)]
        # flip y: font units are y-up
        gs[g].draw(TransformPen(pen, (1, 0, 0, -1, x, 0)))
        gs[g].draw(TransformPen(bpen, (1, 0, 0, -1, x, 0)))
        x += hmtx[g][0] + tracking * upm / 1000
    xmin, ymin, xmax, ymax = bpen.bounds
    cap = f['OS/2'].sCapHeight if hasattr(f['OS/2'], 'sCapHeight') and f['OS/2'].sCapHeight else upm * 0.7
    return dict(d=pen.getCommands(), bounds=[xmin, ymin, xmax, ymax], upm=upm, cap=cap, advance=x)

if __name__ == '__main__':
    path, axes, tracking, out = sys.argv[1], json.loads(sys.argv[2]), float(sys.argv[3]), sys.argv[4]
    json.dump(outline(path, axes, tracking=tracking), open(out, 'w'))
