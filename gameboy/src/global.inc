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
  IF  !DEF(GLOBAL_INC)
GLOBAL_INC SET 1

; Follow this thread:
; http://gbdev.gg8.se/forums/viewtopic.php?pid=3176#p3176
hLocals EQU $FF80
locals_size EQU 16

; RGBASM requires that RST arguments be constexpr, not imported
memset_tiny     EQU $0008
wait_vblank_irq EQU $0010

; CHR RAM is where tile shapes go
CHRRAM0  EQU $8000
CHRRAM1  EQU $8800
CHRRAM2  EQU $9800

; 384-byte temporary buffer in VRAM used for tilemap decompression
; while LCD is off.  An entire screen's worth of tilemap data
; (up to 20x18 cells) fits here, and it's below the visible area
; in activities that don't scroll vertically.
SCRN_TMP EQU $9800+640

; Old Z80 coder habits die hard
djnz: macro
  dec b
  jr nz,\1
  endm

;;
; Syntax: ldxy rp, xpos, ypos[, mapbase]
; Sets a register pair to the address of (x, y) tile coordinates
; within a tilemap.
; @param rp a register pair (BC, DE, HL)
; @param x horizontal distance in tiles from left (0-31)
; @param y vertical distance in tiles from top (0-31)
; @param mapbase start address of 32-cell-wide tilemap:
;   _SCRN0 (default), _SCRN1, or a virtual tilemap in WRAM.
ldxy: macro
  if _NARG < 4
    ld \1, (\3) * SCRN_VX_B + (\2) + _SCRN0
  else
    ld \1, (\3) * SCRN_VX_B + (\2) + (\4)
  endc
  endm

;;
; Syntax: dwxy xpos, ypos[, mapbase]
; Writes an X, Y position within a tilemap as a 16-bit address.
dwxy: macro
  if _NARG < 3
    dw (\2) * SCRN_VX_B + (\1) + _SCRN0
  else
    dw (\2) * SCRN_VX_B + (\1) + (\3)
  endc
  endm

;;
; Syntax: lb rp, high, low
; Sets the high and low bytes of a register pair
lb: macro
  ld \1, ((\2) << 8) | (low(\3))
  endm

  ENDC  ; end include guard
