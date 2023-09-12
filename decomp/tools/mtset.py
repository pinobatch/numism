#!/usr/bin/env python3
"""
Metatileset converter for Mindy's Hike
"""
import os, sys, argparse, re, array
from collections import namedtuple
from PIL import Image, ImageChops
from pilbmp2nes import pilbmp2chr, formatTilePlanar

# tileset metadata parsing ##########################################

def parseint(s):
    if s.startswith("$"): return int(s[1:], 16)
    if s.startswith("0x"): return int(s[2:], 16)
    return int(s)

def isint(s):
    try:
        parseint(s)
    except ValueError:
        return False
    return True

def parse_sections(lines):
    sections, cur_section_name = {}, None
    for line in lines:
        line = line.strip()
        if line == '' or line.startswith("#"): continue
        if line.startswith('[') and line.endswith(']'):
            cur_section_name = line[1:-1].strip()
            sections.setdefault(cur_section_name, [])
            continue
        sections[cur_section_name].append(line)
    return sections

colorRE = re.compile('#([0-9a-fA-F]{3,6})$')
def parse_color(s):
    """Parse a 3 or 6 digit hex color (#FFF or #FFFFFF) into a 3-tuple or None"""
    m = colorRE.match(s)
    if m:
        m = m.group(1)
        if len(m) == 3:
            return tuple(int(c, 16) * 17 for c in m)
        elif len(m) == 6:
            return tuple(int(m[i:i + 2], 16) for i in range(0, 6, 2))
    raise ValueError("color %s not recognized" % s)

def parse_subpalette(words, start=0):
    """Turn palette entry into a list of color-to-index pairs.

words -- an iterable of strings of the form "#ABC", "#ABCDEF",
    "#ABC=1", "#ABCDEF=1"
start -- first index of words without a number

For example, #AAA=2 or #AAAAAA=2 assigns (170, 170, 170) to color 2
in that subpalette.  If no =number is specified, indices are assigned
sequentially, with start as the first.

Return a list of ((r, g, b), index) tuples.
"""
    out = []
    for i, word in enumerate(words):
        color_index = word.split("=", 1)
        color = parse_color(color_index[0])
        index = int(color_index[1]) if len(color_index) > 1 else i + start
        out.append((color, index))
    return out

PaletteLine = namedtuple("PaletteLine", [
    "palid", "nickname", "colors"
])
def parse_palette_line(line, start=0):
    words = line.split()
    palid = parseint(words[1])
    nickname, subpalette_words = None, []
    for word in words[2:]:
        if word.startswith('#'):
            subpalette_words.append(word)
            continue
        if nickname is not None:
            raise ValueError("palette %d has more than one nickname (%s and %s)"
                             % (palid, repr(nickname), repr(word)))
        nickname = word
    if nickname is None: nickname = "ID%d" % palid
    subpalette = parse_subpalette(subpalette_words, start)
    return PaletteLine(palid, nickname, subpalette)

def parse_palettes_section(lines):
    palette_lines = []
    for line in lines:
        first_word = line.split(None, 1)[0]
        if first_word == 'palette':
            palette_lines.append(parse_palette_line(line, 0))
            continue
        raise ValueError("unexpected keyword %s" % repr(first_word))
    return palette_lines

MetatileLine = namedtuple("PaletteLine", [
    "metatile_ids", "nickname"
])
def parse_metatile_line(line):
    metatile_ids, nickname = [], None
    for word in line.split():
        try:
            metatile_id = parseint(word)
        except ValueError:
            pass
        else:
            metatile_ids.append(metatile_id)
            continue
        if nickname is not None:
            raise ValueError("line has more than one nickname (%s and %s)"
                             % (repr(nickname), repr(word)))
        nickname = word

    return MetatileLine(metatile_ids, nickname)

def parse_metatile_section(lines):
    nick_to_id, id_to_nick, chains = {}, {}, {}
    for line in lines:
        result = parse_metatile_line(line)
        first_id = result.metatile_ids[0]
        nick = result.nickname
        if nick is not None:
            old_tile_id = nick_to_id.setdefault(nick, first_id)
            if old_tile_id != first_id:
                raise ValueError("nickname %s has more than one metatile ID (%d and %d)"
                                 % (repr(nick), old_tile_id, first_id))
            old_nick = id_to_nick.setdefault(first_id, nick)
            if old_nick != nick:
                raise ValueError("tile ID %d has more than one nickname (%s and %s)"
                                 % (first_id, repr(old_nick), repr(nick)))
        for top, bottom in zip(result.metatile_ids, result.metatile_ids[1:]):
            old_bottom = chains.setdefault(top, bottom)
            if old_bottom != bottom:
                raise ValueError("tile ID %d has more than one tile below (%d and %d)"
                                 % (top, old_bottom, bottom))
    chains_ls = [0] * (1 + max(chains))
    for k, v in chains.items(): chains_ls[k] = v
    return nick_to_id, id_to_nick, chains_ls

def prep_palette_lines_for_colorround(palette_lines):
    """Convert an extractcels-style palette to a savtool-style palette.

Each element of palette_lines has a colors attribute of value
[((r, g, b), index), ...].

Return a list [[(r, g, b), ...], ...]
"""
    palettes = {}
    for line in palette_lines:
        if line.palid in palettes:
            raise ValueError("duplicate palette %d" % line.palid)
        if not line.colors: continue
        max_color_id = max(c[1] for c in line.colors)
        subpalette = [None] * (1 + max_color_id)
        first_rgb = min(line.colors, key=lambda c: c[1])[0]
        for rgb, index in line.colors:
            if subpalette[index] is not None and subpalette[index] != rgb:
                raise ValueError("palette %d: duplicate color index %d not yet handled"
                                 % (line.palid, index))
            subpalette[index] = rgb

        palettes[line.palid] = [rgb or first_rgb for rgb in subpalette]

    palettes_ls = [()] * (1 + max(palettes))
    for k, v in palettes.items(): palettes_ls[k] = v
    return palettes_ls

# savtool inner loop: color rounding ################################

def quantizetopalette(src, palette, dither=False):
    """Convert an RGB or L mode image to use a given P image's palette.

Requires Pillow 6 or later.
Reference: https://stackoverflow.com/a/29438149/2738262
"""
    return src.quantize(palette=palette, dither=1 if dither else 0)

def colorround(im, palettes, tilesize, subpalsize):
    """Find the best palette for each tile.

im -- a Pillow image (will be converted to RGB)
palettes -- list of subpalettes [[(r, g, b), ...], ...]
tilesize -- size in pixels of each tile as (x, y) tuple
subpalsize -- the maximum number of colors in each subpalette to use

Return a 2-tuple (final image, attribute map)
"""
    # Generalized from a function in savtool.py in nesbgeditor

    blockw, blockh = tilesize
    if im.mode != 'RGB':
        im = im.convert('RGB')

    trials, all_colors = [], []
    onetile = Image.new('P', tilesize)
    for p in palettes:
        p = list(p[:subpalsize])
        p.extend([p[0]] * (subpalsize - len(p)))
        all_colors.extend(p)

        # New images default to a 256-gray palette, and
        # quantizetopalette() uses all of it unless overwritten.
        p.extend([p[0]] * (256 - len(p)))

        # putpalette() requires a flattened palette:
        # [r,g,b,r,g,b,...] not [(r,g,b),(r,g,b),...]
        seq = [component for color in p for component in color]
        onetile.putpalette(seq)
        imp = quantizetopalette(im, onetile)

        # For each color area, calculate the difference
        # between it and the original
        impr = imp.convert('RGB')
        diff = ImageChops.difference(im, impr)
        diff = [
            diff.crop((l, t, l + blockw, t + blockh))
            for t in range(0, im.size[1], blockh)
            for l in range(0, im.size[0], blockw)
        ]
        # diff is the overall color difference for each color area
        # of this image, using weights 2, 4, 3 per
        # https://en.wikipedia.org/w/index.php?title=Color_difference&oldid=840435351
        diff = [
            sum(2*r*r+4*g*g+3*b*b for (r, g, b) in tile.getdata())
            for tile in diff
        ]
        trials.append((imp, diff))

    # trials is a list [(imp, [diff, ...]), ...]
    # where imp is a Pillow image converted using each subpalette,
    # and diff is total squared error from quantization of each tile,
    # arranged row-major.  Find the subpalette with the smallest
    # difference for each color area.
    attrs = [
        min(enumerate(i), key=lambda i: i[1])[0]
        for i in zip(*(diff for (imp, diff) in trials))
    ]

    # Calculate the resulting image
    imfinal = Image.new('P', im.size)
    seq = [component for color in all_colors for component in color]
    imfinal.putpalette(seq)
    tilerects = zip(
        ((l, t, l + blockw, t + blockh)
         for t in range(0, im.size[1], blockh)
         for l in range(0, im.size[0], blockw)),
        attrs
    )
    for tilerect, attr in tilerects:
        pbase = attr * subpalsize
        pixeldata = trials[attr][0].crop(tilerect).getdata()
        onetile.putdata(bytes(pbase + b for b in pixeldata))
        imfinal.paste(onetile, tilerect)
    return imfinal, attrs

# forming metatiles #################################################

# TODO:
# collect imtiles and attrs into 32x16-pixel pieces
# if the right half of a piece is blank, duplicate the left half
# output tiles in format suitable for autotiler

# $00 top left attribute, edge
# $01 bottom left attribute, edge
# $02 top left tile number, edge
# $03 bottom left tile number, edge
# $04 top left attribute, interior
# $05 bottom left attribute, interior
# $06 top left tile number, interior
# $07 bottom left tile number, interior
# $08 top right attribute, edge
# $09 bottom right attribute, edge
# $0A top right tile number, edge
# $0B bottom right tile number, edge
# $0C top right attribute, interior
# $0D bottom right attribute, interior
# $0E top right tile number, interior
# $0F bottom right tile number, interior

def uniq(tiledata, fixtiles=()):
    itiles = {v: k for k, v in enumerate(fixtiles)}
    tilemap = [
        itiles.setdefault(tile, len(itiles)) for tile in tiledata
    ]
    tiles = [None] * len(itiles)
    for tile, i in itiles.items(): tiles[i] = tile
    return tiles, itiles, tilemap

def mtify(tiledata, attrs, tiles_per_row,
          fixtiles=(), base_tile_id=0x00):
    if tiles_per_row <= 0 or tiles_per_row % 4 != 0:
        raise ValueError("tiles_per_row %s not a multiple of 4"
                         % repr(tiles_per_row))
    if len(tiledata) != len(attrs):
        raise ValueError("tiledata length %d does not match attribute length %d"
                         % (len(tiledata), len(attrs)))

    # Pull out tile data and attribute data in this order
    # 0 2 4 6
    # 1 3 5 7
    metatile_defs = [
        [
            (tiledata[i], attrs[i])
            for colstart in range(topleft, topleft + 4)
            for i in (colstart, colstart + tiles_per_row)
        ]
        for rowstart in range(0, len(tiledata), 2 * tiles_per_row)
        for topleft in range(rowstart, rowstart+tiles_per_row, 4)
    ]
    # Duplicate left half into right half if right half is blank
    blank_tile = bytes(len(tiledata[0]))
    for mt in metatile_defs:
        if all(t == blank_tile for t, a in mt[4:]):
            mt[4:] = mt[:4]

    # Now that it's been reordered, calculate unique tiles
    tiles_only = [t[0] for mt in metatile_defs for t in mt]
    utiles, itiles, tilemap = uniq(tiles_only, fixtiles)
    if len(utiles) > 256:
        raise ValueError("too many tiles: %d > 256" % len(utiles))

    # Put the columns in the order left edge, left interior,
    # right edge, right interior
    mt_reorder = [0, 1, 4, 5, 6, 7, 2, 3]
    mtdata = [
        array.array("H", (
            (a << 8) | (itiles[t] + base_tile_id & 0xFF) for t, a in mt
        ))
        for mt in metatile_defs
    ]
    mtdata = array.array("H", (
        mt[i] for mt in mtdata for i in mt_reorder
    ))

    # The metatiler uses big endian to write the GBC before DMG
    # so as to work correctly on both GBC and DMG.
    # Endianness of the interpreter is implementation-defined,
    # and byteswap() is in-place, so it must be done last.
    little = array.array("H", [1]).tobytes()[0]
    if little: mtdata.byteswap()
    return utiles, mtdata.tobytes()

# forming assembly ##################################################

def hexdump(s, width=16):
    print("\n".join(
        "%4x: %s" % (i, s[i:i + width].hex())
        for i in range(0, len(s), width)
    ))


# cli ###############################################################

def parse_argv(argv):
    p = argparse.ArgumentParser()
    p.add_argument("-v", "--verbose", action="store_true",
                   help="show work")
    p.add_argument("descfile")
    p.add_argument("image")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    with open(args.descfile, "r", encoding="utf-8") as infp:
        sections = parse_sections(infp)
    palette_lines = parse_palettes_section(sections["palettes"])
    n2i, i2n, chains = parse_metatile_section(sections["metatiles"])
    crpalettes = prep_palette_lines_for_colorround(palette_lines)
    with Image.open(args.image) as im:
        im = im.convert("RGB")
        im_quantized, attrs = colorround(im, crpalettes, (8, 8), 4)
        im = None
    gbformat = lambda im: formatTilePlanar(im, "0,1")
    imtiles = pilbmp2chr(im_quantized, formatTile=gbformat)
    tiles_per_row = im_quantized.size[0] // 8
    utiles, mtdata = mtify(imtiles, attrs, tiles_per_row)

    print("unique tiles:")
    hexdump(b''.join(utiles))
    print("metatiles:")
    hexdump(mtdata)

    print("Nick to ID")
    print("\n".join(repr(row) for row in n2i.items()))
    print("ID to nick")
    print("\n".join(repr(row) for row in i2n.items()))
    print("Chains")
    print("\n".join("%2d: %2d" % (i, tn) for i, tn in enumerate(chains)))

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main("""
./mtset.py -v ../tilesets/parkmetatiles.mt ../tilesets/parkmetatiles.png
""".split())
    else:
        main()
