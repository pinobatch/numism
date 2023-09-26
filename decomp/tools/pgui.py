#!/usr/bin/env python3
import sys
import pygame as pg

class PopupMenu(object):
    pass

class Menubar(object):
    pass

ink_color = pg.Color(0, 0, 0)
bg_color = pg.Color(204, 204, 204)

def alert_draw_buttons(button_rects, buttons, font, hover=None, focus=None, active=None):
    line_width = (font.ch + 4) // 8
    thick_line_width = (font.ch + 2) // 4
    screen = pg.display.get_surface()
    for i, (r, line) in enumerate(zip(button_rects, buttons)):
        thick = i == hover or i == focus
        border_width = thick_line_width if thick else line_width
        fill_color = ink_color if i == active else bg_color
        text_color = bg_color if i == active else ink_color
        pg.draw.rect(screen, fill_color, r)
        pg.draw.rect(screen, ink_color, r, width=border_width)
        text_left = r.centerx - font.text_size(line)[0] // 2
        text_top = r.centery - font.ch // 2
        font.textout(screen, line, text_left, text_top, text_color)

def alert(text, font, buttons=None, focus=0):
    screen = pg.display.get_surface()
    if buttons is None: buttons = ['OK']
    button_widths = [
        max(5 * font.ch, font.text_size(line)[0] + 2 * font.ch)
        for line in buttons
    ]
    buttons_total_width = sum(button_widths) + (len(button_widths) - 1) * font.ch
    if not 0 <= focus < len(buttons): focus = 0
    sw, sh = screen.get_size()
    prev_screen = screen.copy()
    prev_screen_sm = pg.transform.smoothscale(prev_screen, (sw // 4, sh // 4))
    lines = hover_button = active_button = None
    clock = pg.time.Clock()
    running = True
    line_width = (font.ch + 4) // 8

    # Text is wrapped to 8em less than screen width, for a 2em margin
    # and 2em border+padding around everything.
    # 1em above text, 1em below text, 2em button height, 1em below buttons
    while running:
        keys = []
        lmb_change = None
        for event in pg.event.get():
            if event.type == pg.QUIT:  # close button
                running, want_redraw, focus = False, True, 1
            elif event.type == pg.KEYDOWN:
                keys.append((event.key, event.mod))
            elif event.type == pg.VIDEORESIZE:  # resize
                lines = None
            elif event.type == pg.MOUSEMOTION:
                want_hover_test = event.pos
            elif event.type == pg.MOUSEBUTTONDOWN:
                want_hover_test = event.pos
                if event.button == 1: lmb_change = True
            elif event.type == pg.MOUSEBUTTONUP:
                want_hover_test = event.pos
                if event.button == 1: lmb_change = False

        focus_change = 0
        for key, mod in keys:
            if key in (pg.K_RETURN, pg.K_KP_ENTER, pg.K_SPACE):
                running, want_redraw = False, True
                active_button = focus
            elif key == pg.K_ESCAPE:
                running, want_redraw, focus = False, True, 1
                active_button = focus
            elif key == pg.K_TAB:
                focus_change = -1 if mod & pg.KMOD_SHIFT else 1
            elif key == pg.K_RIGHT:
                focus_change = 1
            elif key == pg.K_LEFT:
                focus_change = -1
        if focus_change:
            want_redraw, focus = True, (focus + focus_change) % len(buttons)

        if lines is None:
            sw, sh = screen.get_size()
            blur_screen = pg.transform.smoothscale(prev_screen_sm, (sw, sh))
            # 2em margin, 2em padding
            lines = font.wrap(text, sw - 8 * font.ch) or [""]
            text_width = max(font.text_size(line)[0] for line in lines)
            text_width = max(text_width, buttons_total_width)
            box_left = (sw - text_width) // 2 - 2 * font.ch
            text_left = box_left + 2 * font.ch
            box_width = text_width + 4 * font.ch
            buttons_left = text_left + text_width - buttons_total_width
            box_height = (5 + len(lines)) * font.ch
            box_top = (sh - box_height) // 3
            buttons_top = box_top + box_height - 3 * font.ch
            box_rect = pg.Rect(box_left, box_top, box_width, box_height)
            want_redraw = True
            want_hover_test = pg.mouse.get_pos()
            active_button = lmb_button = None
            
            button_rects = []
            button_x = buttons_left
            for w in button_widths:
                button_rects.append(pg.Rect(
                    button_x, buttons_top, w, 2 * font.ch
                ))
                button_x += w + font.ch

        if want_hover_test:
            last_hover_button = hover_button
            last_active_button = active_button
            hover_button = None
            for i, r in enumerate(button_rects):
                if r.collidepoint(want_hover_test): hover_button = i
            want_hover_test = False
            active_button = hover_button if hover_button == lmb_button else None
            if lmb_change is True:  # press
                lmb_button = active_button = hover_button
                if lmb_button is not None: focus = lmb_button
            elif lmb_change is False:  # release
                if hover_button == lmb_button and lmb_button is not None:
                    # click complete
                    focus, running, want_redraw = hover_button, False, True
                lmb_button = None
            if last_hover_button != hover_button: want_redraw = True
            if last_active_button != active_button: want_redraw = True

        if want_redraw:
            want_redraw = False
            screen.blit(blur_screen, (0, 0))
            pg.draw.rect(screen, bg_color, box_rect)
            pg.draw.rect(screen, ink_color, box_rect, width=line_width)
            for i, line in enumerate(lines):
                font.textout(screen, line, 
                             text_left, box_top + (1 + i) * font.ch, ink_color)
            alert_draw_buttons(button_rects, buttons, font,
                               hover_button, focus, active_button)
                
            pg.display.flip()

        clock.tick(60)  # limits FPS to 60

    pg.time.wait(100)  # show the highlight
    blur_screen = pg.transform.smoothscale(prev_screen, screen.get_size())
    screen.blit(blur_screen, (0, 0))
    pg.display.flip()
    return focus
