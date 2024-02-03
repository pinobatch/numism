import os, sys, argparse, re, array
from collections import namedtuple

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
    last_tile_id = max(max(chains), max(chains.values()), max(id_to_nick))
    chains_ls = [0] * (1 + last_tile_id)
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

