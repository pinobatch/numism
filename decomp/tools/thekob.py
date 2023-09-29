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
AUTOTILE_INVARIANT = 0
AUTOTILE_EDGES = 1
AUTOTILE_MIDDLEONLY = 2

def mtim_dupe_halves(im, tile_width, tile_height):
    """Decode a side-autotilable metatile sheet.

Where the right half is blank, copy the left half onto the right
half in place.

Return a sequence, one per metatile, of these values:
- AUTOTILE_INVARIANT: left half was copied into blank right half
- AUTOTILE_EDGES: two unique halves
- AUTOTILE_MIDDLEONLY: two unique halves, left and right quarters
  empty, visible only when used in pairs (such as a tree trunk)
"""
    imw, imh = im.get_size()
    tiles_per_row = imw // (tile_width * 2)

    # Look for left-half-only graphics that need to be copied
    # to the right half, or graphics that occupy only the center.
    tilesize = bytearray()
    pxa = pg.PixelArray(im)
    for yt in range(0, imh, tile_height):
        for xt in range(tiles_per_row):
            xt *= tile_height * 2
            target_color = pxa[xt + 2 * tile_width - 1, yt]
            rhalf = pxa[xt + tile_width:xt + 2 * tile_width,
                        yt:yt + tile_height]
            found_rh = any(c != target_color for row in rhalf for c in row)
            lquarter = pxa[xt:xt + tile_width // 2,
                           yt:yt + tile_height]
            found_lq = any(c != target_color for row in lquarter for c in row)
            rquarter = pxa[xt + 3 * tile_width // 2:xt + 2 * tile_width,
                           yt:yt + tile_height]
            found_rq = any(c != target_color for row in rquarter for c in row)
            tilesize.append(
                AUTOTILE_INVARIANT if not found_rh
                else AUTOTILE_MIDDLEONLY if not (found_rq or found_lq)
                else AUTOTILE_EDGES
            )
    pxa.close()

    # Copy left-half-only graphics to the right half.  (Pygame does
    # not allow blitting to or from a surface that has a PixelArray
    # open on it.)
    for i, is_autotiled in enumerate(tilesize):
        if is_autotiled: continue
        yt, xt = divmod(i, tiles_per_row)
        xt *= tile_width * 2
        yt *= tile_height
        srcarea = pg.Rect(xt, yt, tile_width, tile_height)
        im.blit(im, (xt + tile_width, yt), srcarea)
    return bytes(tilesize)

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
        if chains:
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

# document context ##################################################

class HscrollableView(object):
    def __init__(self, width, view_width, increment=16, overscroll=0):
        self.width = width
        self.view_width = view_width
        self.increment = increment
        self.overscroll = overscroll
        self.x = self.xtarget = -overscroll
        self.damping = 8

    def on_left(self):
        self.xtarget -= self.increment

    def on_right(self):
        self.xtarget += self.increment

    def on_wheel_up(self):
        self.xtarget -= 3 * self.increment

    def on_wheel_down(self):
        self.xtarget += 3 * self.increment

    def on_pageup(self):
        self.xtarget -= self.view_width - 2 * self.increment

    def on_pagedown(self):
        self.xtarget += self.view_width - 2 * self.increment

    def on_home(self):
        self.xtarget = -self.overscroll

    def on_end(self):
        self.xtarget = self.width

    def update(self):
        vw = self.view_width
        os = self.overscroll
        damp = self.damping
        camx = self.x

        # Clamp target scroll position
        xtarget = min(self.xtarget, self.width + os - vw)
        self.xtarget = xtarget = max(xtarget, -self.overscroll)

        # Clamp displacement to one view width
        camxdiff = max(min(xtarget - camx, vw), -vw)

        # Move a fraction of that, rounding away from zero
        camx += (camxdiff + (damp - 1 if camxdiff > 0 else 0)) // damp
        self.x = camx
        return camx

    def hittest(self, mouse_pos):
        return None

class KobView(object):
    def __init__(self):
        pass

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

    mtsetname = "../tilesets/parkmetatiles.mt"
    mtimname = "../tilesets/parkmetatiles.png"
    fontname = "Fauxtura14.png"

    with open(mtsetname, "r", encoding="utf-8") as infp:
        mtset_sections = mtsetparse.parse_sections(infp)
    result = mtsetparse.parse_metatile_section(mtset_sections["metatiles"])
    _, _, chains = result

    pg.init()
    pg.display.set_caption("Numism Builder")
    screen = pg.display.set_mode((800, 480), pg.RESIZABLE)
    mtim = pg.image.load(mtimname).convert()
    mthalves = mtim_dupe_halves(mtim, TILE_WIDTH, TILE_HEIGHT)
    print("mthalves is %s" % repr(mthalves))
    futu_png = pg.image.load(os.path.join(progpath, fontname))
    futu_png.set_colorkey(0)
    font = pgbmfont.BMFont(futu_png, 16, 16, ord(" "), sepColor=2)

    mapim = render_tilemap(mtim, chains, mtmap,
                           explicitcolor=(0, 0, 0))

    mapcam = HscrollableView(mapim.get_width(), screen.get_width(),
                             TILE_WIDTH, TILE_WIDTH)
    palettecam = HscrollableView(mtim.get_width(), screen.get_width(),
                                 TILE_WIDTH, TILE_WIDTH)
    focused_cam = mapcam
    clock = pg.time.Clock()
    running = True
    while running:
        # poll for events
        keys, mouse_events = [], []
        for event in pg.event.get():
            if event.type == pg.QUIT:  # close button
                running = False
            elif event.type == pg.KEYDOWN:
                keys.append((event.key, event.mod))
            elif event.type == pg.MOUSEBUTTONDOWN:
                mouse_events.append((event.button, event.pos))
            elif event.type == pg.MOUSEBUTTONUP:
                mouse_events.append((-event.button, event.pos))
            elif event.type == pg.MOUSEMOTION:
                mouse_events.append((0, event.pos))
            else:
                print(repr(event), file=sys.stderr)

        # Notify cameras of view resize
        mapcam.view_width = palettecam.view_width = screen.get_width()

        palette_top = font.ch * 2
        palette_bottom = palette_top + mtim.get_height()
        map_top = palette_bottom + font.ch
        map_bottom = map_top + mapim.get_height()

        for button, pos in mouse_events:
            m_y = pos[1]
            if palette_top <= m_y < palette_bottom:
                focused_cam = palettecam
            elif map_top <= m_y < map_bottom:
                focused_cam = mapcam
            if button == 4:
                focused_cam.on_wheel_up()
            elif button == 5:
                focused_cam.on_wheel_down()

        for key, mod in keys:
            if key == pg.K_q and (mod & pg.KMOD_CTRL):
                running = False
            elif key == pg.K_HOME:
                mapcam.on_home()
            elif key == pg.K_END:
                mapcam.on_end()
            elif key == pg.K_LEFT:
                mapcam.on_left()
            elif key == pg.K_RIGHT:
                mapcam.on_right()
            elif key == pg.K_PAGEUP:
                mapcam.on_pageup()
            elif key == pg.K_PAGEDOWN:
                mapcam.on_pagedown()

        # erase last frame and draw new frame
        screen.fill((192, 192, 192))
        font.textout(screen, "loaded", font.ch, font.ch, (0, 0, 0))
        palettecam.update()
        screen.blit(mtim, (-palettecam.x, palette_top))
        mapcam.update()
        screen.blit(mapim, (-mapcam.x, map_top))

        focusrect = None
        if focused_cam is palettecam:
            focusrect = pg.Rect(0, palette_top - 1,
                                screen.get_width(), palette_bottom - palette_top + 2)
        elif focused_cam is mapcam:
            focusrect = pg.Rect(0, map_top - 1,
                                screen.get_width(), map_bottom - map_top + 2)
        if focusrect:
            pg.draw.rect(screen, (0, 0, 0), focusrect, width=1)

        # present the frame
        pg.display.flip()
        clock.tick(60)

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

