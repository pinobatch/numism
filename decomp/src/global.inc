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

  ENDC
