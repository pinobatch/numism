.ifndef GLOBAL_INC
.define GLOBAL_INC

; init.s
.global reset_handler

; main.s
.global OAM
.global main, nmi_handler, irq_handler
.globalzp cur_keys, new_keys, oam_used, nmis

; continue.s
.global continue_main

; coinss
.global coin_names, coin_routines

; bg.s
.global draw_bg

; player.s
.global init_player, move_player

; pads.s
.global read_pads

; ppuclear.s
.global ppu_clear_nt, ppu_clear_oam, ppu_screen_on

; vwf_draw.s
.global clearLineImg, vwfPutTile, vwfPuts, invertTiles
.global copyLineImg_helpscreen

; bankcall ids
.globalzp load_continue_chr

.endif
