  IF  !DEF(GLOBAL_INC)
DEF GLOBAL_INC EQU 1

; call graph annotation ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

macro fallthrough
  assert (\1) == @
endm

macro calls
endm

macro tailcalls
endm

macro jumptable
endm

macro local
endm

; for things still noet yet ported to SAVE
; http://gbdev.gg8.se/forums/viewtopic.php?pid=3176#p3176
DEF hLocals EQU $FF80
DEF locals_size EQU 16

; the width of the area that can affect autotiling of onscreen tiles
def MAP_VICINITY_WIDTH_MT equ 16
def MAP_COLUMN_HEIGHT_MT equ 16
def MT_WIDTH_CHARS equ 2
def MT_HEIGHT_CHARS equ 2

def TEXTWINDOW_ROWS equ 5

;;
; Syntax: drgb $FF9966 for color #FF9966
; Divides each hex tuplet by 8 and rounds down, forming an RGB555
; color word suitable for SNES/SGB or GBC/GBA/DS.
macro drgb
  REPT _NARG
    dw (\1 & $F80000) >> 19 | (\1 & $00F800) >> 6 | (\1 & $0000F8) << 7
    shift 1
  ENDR
endm

;;
; Syntax: lb rp, hivalue, lovalue
; Loads hivalue into the upper register of a pair (B, D, or H)
; and lovalue into the lower register of the same pair (C, E, or L).
macro lb
  ld \1, low(\2) << 8 | low(\3)
endm

  ENDC
