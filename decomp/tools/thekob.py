#!/usr/bin/env python3
import os, sys, argparse
import pygame as pg
import mtsetparse, pgbmfont, pgui

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

class Tileset(object):
    def __init__(self, im, lines):
        pass

def parse_argv(argv):
    p = argparse.ArgumentParser()
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
##    print(args)
    progpath = os.path.dirname(sys.argv[0])

    mtsetname = "../tilesets/parkmetatiles.mt"
    mtimname = "../tilesets/parkmetatiles.png"
    fontname = "Fauxtura14.png"

    pg.init()
    screen = pg.display.set_mode((800, 480), pg.RESIZABLE)
    mtim = pg.image.load(mtimname).convert()
    mtim_dupe_left_halves_into_blank_right_halves(mtim, 16, 16)
    futu_png = pg.image.load(os.path.join(progpath, fontname))
    futu_png.set_colorkey(0)
    font = pgbmfont.BMFont(futu_png, 16, 16, ord(" "), sepColor=2)

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
        screen.fill((170, 170, 255))
        font.textout(screen, "loaded", font.ch, font.ch, (255, 255, 255))
        screen.blit(mtim, (font.ch, font.ch * 2))

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

