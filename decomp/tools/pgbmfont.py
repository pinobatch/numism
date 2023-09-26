#!/usr/bin/env python3
"""
bitmap font drawing for Pygame
Copyright 2012, 2023 Damian Yerrick

License: zlib
"""
import re
import pygame as pg

def vwfscan_at(pxa, xt, yt, tw, sepColor):
    """Scan along a scanline for pixels other than the separator color.

Think of it as like "strnlen".  It finds the length of the run of
pixels starting at (xt, yt) and going right that does not match
sepColor, not exceeding tw pixels.

"""
    pxslice = pxa[xt:xt + tw,yt]
    for x in range(tw):
        if pxslice[x] == sepColor:
            return x
    return tw

class BMFont(object):
    def __init__(self, glyphSurface, glyphWidth, glyphHeight,
                 firstChar=0, sepColor=None):
        self.img = glyphSurface
        self.cw = glyphWidth
        self.ch = glyphHeight
        self.firstcp = firstChar
        if sepColor is not None:
            vwf_table = []
            pxa = pg.PixelArray(glyphSurface)
            w, h = glyphSurface.get_size()
            for yt in range(0, h, glyphHeight):
                for xt in range(0, w, glyphWidth):
                    vwf_table.append(vwfscan_at(pxa, xt, yt, glyphWidth, sepColor))
        else:
            vwf_table = None
        self.vwf_table = vwf_table

    def text_size(self, txt):
        if not self.vwf_table:  # fixed width
            return (len(txt) * self.cw, self.ch)
        txt1 = (ord(c) - self.firstcp for c in txt)
        return (sum(self.vwf_table[c] for c in txt1 if 0 <= c < len(self.vwf_table)),
                self.ch)

    def textout(self, dstSurface, txt, x, y, color=None):
        if color is not None:
            self.img.set_palette_at(1, color or (255, 255, 255))
        rowsz = self.img.get_width() // self.cw
        startx = x
        wids = self.vwf_table
        for c in txt:
            c = ord(c) - self.firstcp
            if c < 0: continue
            rownum = c // rowsz
            charnum = c % rowsz
            cw = self.cw
            if wids: cw = wids[c] if c < len(wids) else 0
            srcarea = pg.rect.Rect(charnum * self.cw, rownum * self.ch,
                                   cw, self.ch)
            dstSurface.blit(self.img, (x, y), srcarea)
            x += cw
        return (startx, y, x - startx, self.ch)        

    spacesplitRE = re.compile(r"""\n|\S+|\s+""")

    def wrap(self, text, width):
        out, cum_width = [""], 0
        for word in self.spacesplitRE.findall(text):
            sz = self.text_size(word)[0]
            if word[0] == '\n':
                out.append("")
                cum_width = 0
            elif word[0].isspace() or sz + cum_width <= width:
                out[-1] += word
                cum_width += sz
            else:
                out.append(word)
                cum_width = sz
        return out
