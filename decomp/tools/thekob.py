#!/usr/bin/env python3
import os, sys, argparse
from itertools import zip_longest as zippad
import pygame as pg
import mtsetparse, pgbmfont, pgui

class Tileset(object):
    def __init__(self, im, lines):
        pass

# Placeholder tilemap parsing #######################################

mtbody = """
. . . . . . . . 01. . . . . . . 
. . . . . . . . 01. . . . . . . 
. . . . . . . . 01. . . . . . . 
. . . . . . . . 01. . . . . . . 
. . . . . . . . 01. . . . . . . 
. . . . . . . . 01. . . . . . . 
. . . 0e. . . 06. . . . . . . . 
. . . 0e. . . . 01. . . . . . . 
. . . 0e. . . . . . 01. . . . . 
. . . . . . . . . . 01. . . . . 
. . . . . . . . . 10. . . . . . 
. . . . . . . . . . 01. . . . . 
. . . . . . . . . 11. . . . . . 
. . . . . . . . . . 01. . . . . 
. . . . . . . . . 06. . . . . . 
. . . . . . . . . . 01. . . . . 
"""

def mtmap_parse_column_line(s, code_to_id=None):
    blkcodes = s.replace(".", " ").rstrip()
    blkcodes = [blkcodes[i:i + 2].strip() for i in range(0, len(blkcodes), 2)]
    out = bytearray(len(blkcodes))
    errors = bytearray(len(blkcodes))
    for i, code in enumerate(blkcodes):
        value = 0 if code == '' else code_to_id.get(i) if code_to_id else None
        if value is None:
            try:
                value = int(code, 16)
            except ValueError:
                errors[i] = 1
                value = 0
        out[i] = value
    return out, errors if any(errors) else None

def ls_chop_leading_trailing_falses(lines):
    """Remove leading and trailing false elements from a mutable sequence"""
    while lines and not lines[0]: del lines[0]
    while lines and not lines[-1]: del lines[-1]

def parse_mtmap(lines, code_to_id=None, height=16):
    out = []
    all_errors = []

    for i, s in enumerate(lines):
        parsed, errors = mtmap_parse_column_line(s, code_to_id)
        parsed = bytes(parsed[:height])
        parsed = parsed + bytes(height - len(parsed))
        out.append(parsed)
        if errors:
            all_errors.append((i, s, errors))
    return out, all_errors

# drawing a tilemap #################################################

TILE_WIDTH = TILE_HEIGHT = 16

def mtim_dupe_left_halves_into_blank_right_halves(im, tile_width, tile_height):
    imw, imh = im.get_size()
    pxa = pg.PixelArray(im)
    copies = []
    for yt in range(0, imh, tile_height):
        for xt in range(0, imw, tile_width * 2):
            target_color = pxa[xt + tile_width, yt]
            # TODO: convert to pygame.transform.threshold()
            for y in range(yt, yt + tile_height):
                pxslice = pxa[xt + tile_width:xt + 2 * tile_width, y]
                found = any(pxslice[x] != target_color
                            for x in range(tile_width))
                if found: break
            # Pygame does not allow blitting if a PixelArray is open
            if not found: copies.append((xt, yt))
    pxa.close()

    for xt, yt in copies:
        srcarea = pg.Rect(xt, yt, tile_width, tile_height)
        im.blit(im, (xt + tile_width, yt), srcarea)


def update_column(im, mtim, chains, mtmap, xt,
                  gridcolor=None, explicitcolor=None):
    if xt < 0 or xt >= len(mtmap): return
    prev_xt = max(0, xt - 1)
    next_xt = min(xt + 1, len(mtmap) - 1)
    lprev = cprev = rprev = 0
    tiles_per_row = mtim.get_width() // (TILE_WIDTH * 2)
    for yt, (l, c, r) in enumerate(zippad(
        mtmap[prev_xt], mtmap[xt], mtmap[next_xt], fillvalue=0
    )):
        boxcolor = explicitcolor if c else gridcolor
        lprev = l = l or chains[lprev]
        cprev = c = c or chains[cprev]
        rprev = r = r or chains[rprev]
        loffset = TILE_WIDTH if l == c else 0
        roffset = (TILE_WIDTH if r != c else 0) + TILE_WIDTH // 2
        src_y, src_x = divmod(c, tiles_per_row)
        src_x *= TILE_WIDTH * 2
        src_y *= TILE_HEIGHT
        srcarea = pg.Rect(src_x + loffset, src_y, TILE_WIDTH // 2, TILE_HEIGHT)
        dst_x, dst_y = xt * TILE_WIDTH, yt * TILE_HEIGHT
        im.blit(mtim, (dst_x, dst_y), srcarea)
        srcarea = pg.Rect(src_x + roffset, src_y, TILE_WIDTH // 2, TILE_HEIGHT)
        im.blit(mtim, (dst_x + TILE_WIDTH // 2, dst_y), srcarea)
        if boxcolor:
            boxrect = (dst_x, dst_y, TILE_WIDTH, TILE_HEIGHT)
            pg.draw.rect(im, boxcolor, boxrect, width=1)

def render_tilemap(mtim, chains, mtmap,
                  gridcolor=None, explicitcolor=None):
    w_tiles, h_tiles = len(mtmap), max(len(x) for x in mtmap)
    im = pg.Surface((w_tiles * TILE_WIDTH, h_tiles * TILE_HEIGHT))
    for xt in range(w_tiles):
        update_column(im, mtim, chains, mtmap, xt,
                      gridcolor, explicitcolor)
    return im

# the front end #####################################################

def parse_argv(argv):
    p = argparse.ArgumentParser()
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
##    print(args)
    progpath = os.path.dirname(sys.argv[0])

    lines = mtbody.split("\n")
    ls_chop_leading_trailing_falses(lines)
    mtmap, mtmap_errors = parse_mtmap(lines)
    print("\n".join(x.hex() for x in mtmap))

    mtsetname = "../tilesets/parkmetatiles.mt"
    mtimname = "../tilesets/parkmetatiles.png"
    fontname = "Fauxtura14.png"

    with open(mtsetname, "r", encoding="utf-8") as infp:
        mtset_sections = mtsetparse.parse_sections(infp)
    result = mtsetparse.parse_metatile_section(mtset_sections["metatiles"])
    _, _, chains = result
    print(chains)

    pg.init()
    screen = pg.display.set_mode((800, 480), pg.RESIZABLE)
    mtim = pg.image.load(mtimname).convert()
    mtim_dupe_left_halves_into_blank_right_halves(mtim, TILE_WIDTH, TILE_HEIGHT)
    futu_png = pg.image.load(os.path.join(progpath, fontname))
    futu_png.set_colorkey(0)
    font = pgbmfont.BMFont(futu_png, 16, 16, ord(" "), sepColor=2)

    mapim = render_tilemap(mtim, chains, mtmap,
                           explicitcolor=(0, 0, 0))

    clock = pg.time.Clock()
    running = True
    pgui.alert("Welcome to editor!", font, ["OK"])
    while running:
        # poll for events
        keys = []
        for event in pg.event.get():
            if event.type == pg.QUIT:  # close button
                running = False
            elif event.type == pg.KEYDOWN:
                keys.append((event.key, event.mod))
            else:
                print(repr(event), file=sys.stderr)

        for key, mod in keys:
            if key == pg.K_q and (mod & pg.KMOD_CTRL):
                running = False

        # erase last frame and draw new frame
        screen.fill((192, 192, 192))
        font.textout(screen, "loaded", font.ch, font.ch, (0, 0, 0))
        screen.blit(mtim, (font.ch, font.ch * 2))
        screen.blit(mapim, (font.ch, font.ch * 3 + mtim.get_height()))

        # flip() the display to put your work on screen
        pg.display.flip()

        clock.tick(60)  # limits FPS to 60
    chosen = pgui.alert("Save changes to Park over the past 120 minutes?",
                        font, ["Discard", "Cancel", "Save"], 2)
    print("Chose %d" % chosen)

    pg.quit()

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main("""
./thekob.py
""".split())
    else:
        main()

