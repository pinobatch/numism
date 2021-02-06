.ifndef POPSLIDE_INC
POPSLIDE_INC = 1

.define NTXY(xt,yt) ($2000 | ((xt)&$1F) | (((yt)&$1F)<<5))

; flags in length byte
NSTRIPE_RUN = $40   ; run of a single byte instead
NSTRIPE_DOWN = $80  ; add 32 instead of 1

; popslide*.s variables
popslide_buf = $0100
POPSLIDE_SLACK = 8  ; for irq's sake

.globalzp popslide_used

; popslide*.s methods
.global popslide_blit, popslide_return
.global popslide_init, popslide_clearbuf
.global popslide_terminate_blit, popslide_blit

; popslide*.s callbacks
.global popslide_return

; nstripe.s
nstripe_srclo = $00
nstripe_srchi = $01
nstripe_left = $02
nstripe_top = $03
nstripe_width = $04
nstripe_height = $05
.global nstripe_draw_rect
.global nstripe_append, nstripe_append_yhi, nstripe_append_tophi
.global nstripe_append_src
.global nstripe_append_64_to_ay, nstripe_append_128_to_ay

.endif