#!/usr/bin/env python3
import os, sys, argparse, bisect
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

    def load_mtset(self, lines, im):
        mtset_sections = mtsetparse.parse_sections(lines)
        result = mtsetparse.parse_metatile_section(mtset_sections["metatiles"])
        _, self.mtid_to_nick, self.mtchains = result
        self.mtids_with_nick = sorted(self.mtid_to_nick)
        self.mtim = im.convert()
        self.mthalves = mtim_dupe_halves(self.mtim, TILE_WIDTH, TILE_HEIGHT)
        self.make_markov_picker()
        self.picker_is_markov = True
        self.mtmap_is_markov = True
        self.mtmap_grid_level = 1
        self.painting_tile = 1

    def load_font(self, im, max_width, max_height,
                  first_char=" ", sep_color=2):
        im.set_colorkey(0)
        if isinstance(first_char, str): first_char = ord(first_char)
        self.font = pgbmfont.BMFont(im, max_width, max_height,
                                    first_char, sep_color)

    def render_tilemap(self, mtmap, gridcolor=None, explicitcolor=None,
                       markov=True):
        return render_tilemap(self.mtim, self.mtchains if markov else None,
                              mtmap, gridcolor, explicitcolor)

    def make_markov_picker(self):
        mtmap = [
            bytes([x, 0, 0, 0])
            for x in self.mtids_with_nick for xsub in (0, 1)
        ]
        self.markov_picker_im = self.render_tilemap(mtmap)

    def make_mapim(self):
        g_l = self.mtmap_grid_level
        ecolor = (0, 0, 0) if g_l >= 1 else None
        gcolor = (128, 128, 128) if g_l >= 2 else None
        print("markov: %s" % repr(self.mtmap_is_markov))
        self.mapim = self.render_tilemap(
            self.mtmap, explicitcolor=ecolor, gridcolor=gcolor,
            markov=self.mtmap_is_markov
        )

    def init_cameras(self):
        screen = pg.display.get_surface()
        self.focused_cam = self.mapcam = HscrollableView(
            self.mapim.get_width(), screen.get_width(), TILE_WIDTH, TILE_WIDTH
        )
        self.palettecam = HscrollableView(
            self.mtim.get_width(), screen.get_width(), TILE_WIDTH, TILE_WIDTH
        )

    def update_layout(self):
        screen = pg.display.get_surface()
        s_w = screen.get_width()
        em = self.font.ch
        mtim = self.markov_picker_im if self.picker_is_markov else self.mtim
        self.mapcam.view_width = self.palettecam.view_width = s_w
        self.palettecam.width = mtim.get_width()
        self.mapcam.width = self.mapim.get_width()
        self.palette_top = 2 * em
        self.palette_bottom = self.palette_top + mtim.get_height()
        self.map_top = self.palette_bottom + em
        self.map_bottom = self.map_top + self.mapim.get_height()

    def update_focus_by_mouse(self, pos):
        m_y = pos[1]
        if self.palette_top <= m_y < self.palette_bottom:
            self.focused_cam = self.palettecam
        elif self.map_top <= m_y < self.map_bottom:
            self.focused_cam = self.mapcam

    def toggle_focused_grid(self):
        if self.focused_cam is self.mapcam:
            self.mtmap_grid_level = (self.mtmap_grid_level + 1) % 3
            self.make_mapim()

    def toggle_focused_markov(self):
        if self.focused_cam is self.mapcam:
            self.mtmap_is_markov = not self.mtmap_is_markov
            self.make_mapim()
        elif self.focused_cam is self.palettecam:
            self.picker_is_markov = not self.picker_is_markov

    def paint_elements(self):
        screen = pg.display.get_surface()
        s_w = screen.get_width()
        em = self.font.ch
        mtim = self.markov_picker_im if self.picker_is_markov else self.mtim
        tile_name = self.mtid_to_nick.get(self.painting_tile, '<unknown>')
        tile_name = "%s (%d)" % (tile_name, self.painting_tile)
        self.font.textout(screen, tile_name, 1 * em, 1 * em, (0, 0, 0))
        self.palettecam.update()
        screen.blit(mtim, (-self.palettecam.x, self.palette_top))
        self.mapcam.update()
        screen.blit(self.mapim, (-self.mapcam.x, self.map_top))

        focusrect = None
        if self.focused_cam is self.palettecam:
            focus_ht = self.palette_bottom - self.palette_top + 2
            focusrect = pg.Rect(0, self.palette_top - 1, s_w, focus_ht)
        elif self.focused_cam is self.mapcam:
            focus_ht = self.map_bottom - self.map_top + 2
            focusrect = pg.Rect(0, self.map_top - 1, s_w, focus_ht)
        if focusrect:
            pg.draw.rect(screen, (0, 0, 0), focusrect, width=1)

        if self.picker_is_markov:
            picker_y = 0
            try:
                picker_x = self.mtids_with_nick.index(self.painting_tile)
            except ValueError:
                picker_x = None
        else:
            tiles_per_row = self.mtim.get_width() // (TILE_WIDTH * 2)
            picker_y, picker_x = divmod(self.painting_tile, tiles_per_row)
        if picker_x is not None:
            pickerrect = pg.Rect(
                picker_x * TILE_WIDTH * 2 - self.palettecam.x,
                picker_y * TILE_HEIGHT + self.palette_top,
                TILE_WIDTH * 2, TILE_HEIGHT
            )
            pg.draw.rect(screen, (0, 0, 0), pickerrect, width=1)

        bottom_row_cues = ["F1: Help"]
        self.font.textout(screen, "; ".join(bottom_row_cues),
                          1 * em, screen.get_height() - 1 * em, (0, 0, 0))


    def num_metatiles(self):
        tiles_per_row = self.mtim.get_width() // (TILE_WIDTH * 2)
        num_rows = self.mtim.get_height() // TILE_HEIGHT
        return tiles_per_row * num_rows

    def set_next_painting_tile(self):
        if self.picker_is_markov:
            index = bisect.bisect_right(self.mtids_with_nick, self.painting_tile)
            if index >= len(self.mtids_with_nick): index = 0
            self.painting_tile = self.mtids_with_nick[index]
        else:
            self.painting_tile += 1
            if self.painting_tile >= self.num_metatiles():
                self.painting_tile = 0

    def set_previous_painting_tile(self):
        if self.picker_is_markov:
            index = bisect.bisect_left(self.mtids_with_nick, self.painting_tile) - 1
            if index < 0: index = len(self.mtids_with_nick) - 1
            self.painting_tile = self.mtids_with_nick[index]
        else:
            self.painting_tile -= 1
            if self.painting_tile < 0:
                self.painting_tile = self.num_metatiles() - 1

# the front end #####################################################

def parse_argv(argv):
    p = argparse.ArgumentParser()
    return p.parse_args(argv[1:])

help_texts = ["""Keyboard

Arrows, PageUp, PageDown: scroll
Home, End: scroll to ends
, (comma) and . (period): choose block
M: toggle Markov mode in map or palette
G: toggle grid in map
""","""Mouse

Wheel: scroll
"""]

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
    view = KobView()
    view.load_font(pg.image.load(os.path.join(progpath, fontname)), 16, 16)
    with open(mtsetname, "r", encoding="utf-8") as infp:
        mtset_lines = list(infp)
    view.load_mtset(mtset_lines, pg.image.load(mtimname))
    del mtset_lines
    view.mtmap = mtmap
    view.make_mapim()
    view.init_cameras()
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

        view.update_layout()

        for button, pos in mouse_events:
            view.update_focus_by_mouse(pos)
            if button == 4:
                view.focused_cam.on_wheel_up()
            elif button == 5:
                view.focused_cam.on_wheel_down()

        for key, mod in keys:
            if key == pg.K_q and (mod & pg.KMOD_CTRL):
                running = False
            elif key == pg.K_HOME:
                view.focused_cam.on_home()
            elif key == pg.K_END:
                view.focused_cam.on_end()
            elif key == pg.K_LEFT:
                view.focused_cam.on_left()
            elif key == pg.K_RIGHT:
                view.focused_cam.on_right()
            elif key == pg.K_PAGEUP:
                view.focused_cam.on_pageup()
            elif key == pg.K_PAGEDOWN:
                view.focused_cam.on_pagedown()
            elif key == pg.K_g:
                view.toggle_focused_grid()
            elif key == pg.K_m:
                view.toggle_focused_markov()
            elif key == pg.K_PERIOD:
                view.set_next_painting_tile()
            elif key == pg.K_COMMA:
                view.set_previous_painting_tile()
            elif key == pg.K_F1:
                pgui.help(help_texts, view.font)

        # erase last frame and draw new frame
        screen.fill((192, 192, 192))
        view.paint_elements()

        # present the frame
        pg.display.flip()
        clock.tick(60)

    chosen = pgui.alert("Save changes to Park over the past 120 minutes?",
                        view.font, ["Discard", "Cancel", "Save"], 2)
    print("Chose %d" % chosen)

    pg.quit()

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main("""
./thekob.py
""".split())
    else:
        main()

