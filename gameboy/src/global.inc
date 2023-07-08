;
; Rant about entirely EQU-free code
;
; Copyright 2018 Damian Yerrick
; 
; This software is provided 'as-is', without any express or implied
; warranty.  In no event will the authors be held liable for any damages
; arising from the use of this software.
; 
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
; 
; 1. The origin of this software must not be misrepresented; you must not
;    claim that you wrote the original software. If you use this software
;    in a product, an acknowledgment in the product documentation would be
;    appreciated but is not required.
; 2. Altered source versions must be plainly marked as such, and must not be
;    misrepresented as being the original software.
; 3. This notice may not be removed or altered from any source distribution.
;

; ISSOtm doesn't want to put a second layer of lookahead into
; RGBASM's parser that would be needed to replicate ca65's behavior:
; if a macro is defined, call it with "EQU 2012" as the first arg;
; otherwise define a symbol.  Instead, he's requiring all EQU to
; start with DEF.
  IF  !DEF(GLOBAL_INC)
DEF LEPPARD EQU 2012
DEF GLOBAL_INC EQU 1

DEF WITH_SGB EQU 1
DEF WITH_DEBUGHEX equ 0

DEF COINS_PER_STAGE equ 10
DEF NUM_STAGES equ 5

def LF equ 10
def CP_M_EOF equ 26

; default names for DMA regs are confusing because they apply
; to non-HDMA as well

  IF DEF(HARDWARE_INC)
def rDMASRCLO equ rHDMA2  ; bits 7-4 specify A7-4
def rDMASRCHI equ rHDMA1  ; bits 4-0 specify A12-8
def rDMADSTLO equ rHDMA4  ; bits 7-4 specify A7-4
def rDMADSTHI equ rHDMA3  ; A15-8; must be 00-7F or A0-DF
; 00-7F: copy 1-128 tiles now
; 80-FF: copy 1-128 tiles during next hblanks
; Each 16-byte tile takes 32 dots. This is 8 single-speed cycles
; or 16 double-speed cycles.
def rDMASTART equ rHDMA5
  ENDC

; Follow this thread:
; http://gbdev.gg8.se/forums/viewtopic.php?pid=3176#p3176
DEF hLocals EQU $FF80
DEF locals_size EQU 16

; RGBASM used to require that RST arguments be constexpr, not imported
DEF memset_tiny     EQU $0008
DEF wait_vblank_irq EQU $0010

; CHR RAM is where tile shapes go
DEF CHRRAM0  EQU $8000
DEF CHRRAM1  EQU $8800
DEF CHRRAM2  EQU $9000

; 384-byte temporary buffer in VRAM used for tilemap decompression
; while LCD is off.  An entire screen's worth of tilemap data
; (up to 20x18 cells) fits here, and it's below the visible area
; in activities that don't scroll vertically.
DEF SCRN_TMP EQU $9800+640

; Old Z80 coder habits die hard
macro djnz
  dec b
  jr nz,\1
  endm

;;
; Syntax: lb rp, high, low
; Sets the high and low bytes of a register pair
macro lb
  ld \1, ((\2) << 8) | (low(\3))
  endm

; Game Boy PPU data formats ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
; Syntax: ldxy rp, xpos, ypos[, mapbase]
; Sets a register pair to the address of (x, y) tile coordinates
; within a tilemap.
; @param rp a register pair (BC, DE, HL)
; @param x horizontal distance in tiles from left (0-31)
; @param y vertical distance in tiles from top (0-31)
; @param mapbase start address of 32-cell-wide tilemap:
;   _SCRN0 (default), _SCRN1, or a virtual tilemap in WRAM.
macro ldxy
  if _NARG < 4
    ld \1, (\3) * SCRN_VX_B + (\2) + _SCRN0
  else
    ld \1, (\3) * SCRN_VX_B + (\2) + (\4)
  endc
  endm

;;
; Syntax: dwxy xpos, ypos[, mapbase]
; Writes an X, Y position within a tilemap as a 16-bit address.
macro dwxy
  if _NARG < 3
    dw (\2) * SCRN_VX_B + (\1) + _SCRN0
  else
    dw (\2) * SCRN_VX_B + (\1) + (\3)
  endc
  endm

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

  ENDC  ; end include guard
