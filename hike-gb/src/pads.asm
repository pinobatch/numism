;
; Controller reading for Game Boy and Super Game Boy
;
; Copyright 2018, 2020 Damian Yerrick
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
include "src/hardware.inc"

def DAS_DELAY equ 15
def DAS_SPEED equ 3

SECTION "hram_pads", HRAM
hCurKeys:: ds 1
hNewKeys:: ds 1
hLastKeyLY:: ds 1

SECTION "ram_pads", WRAM0
das_keys:: ds 1
das_timer:: ds 1
wJoyIRQCapability:: ds 1

SECTION "rom_pads", ROM0

; Controller reading ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This controller reading routine is optimized for size.
; It stores currently pressed keys in hCurKeys (1=pressed) and
; keys newly pressed since last read in hNewKeys, with the same
; nibble ordering as the Game Boy Advance.
; 76543210
; |||||||+- A
; ||||||+-- B
; |||||+--- Select
; ||||+---- Start
; |||+----- Right
; ||+------ Left
; |+------- Up
; +-------- Down
;           R
;           L (just kidding)

read_pad::
  ; Poll half the controller
  ld a,P1F_GET_BTN
  call .onenibble
  ld b,a  ; B7-4 = 1; B3-0 = unpressed buttons

  ; Poll the other half
  ld a,P1F_GET_DPAD
  call .onenibble
  swap a   ; A3-0 = unpressed directions; A7-4 = 1
  xor b    ; A = pressed buttons + directions
  ld b,a   ; B = pressed buttons + directions

  ; And release the controller
  ld a,P1F_GET_NONE
  ldh [rP1],a

  ; Combine with previous hCurKeys to make hNewKeys
  ldh a,[hCurKeys]
  xor b    ; A = keys that changed state
  and b    ; A = keys that changed to pressed
  ldh [hNewKeys],a
  ld a,b
  ldh [hCurKeys],a
  ret

.onenibble:
  ldh [rP1],a     ; switch the key matrix
  call .knownret  ; burn 10 cycles calling a known ret
  ldh a,[rP1]     ; ignore value while waiting for the key matrix to settle
  ldh a,[rP1]
  ldh a,[rP1]     ; this read counts
  or $F0   ; A7-4 = 1; A3-0 = unpressed keys
.knownret:
  ret

;;
; Adds held keys to hNewKeys, DAS_DELAY frames after press and
; every DAS_SPEED frames thereafter
; @param B which keys are eligible for autorepeat
autorepeat::
  ; If no eligible keys are held, skip all autorepeat processing
  ldh a,[hCurKeys]
  and b
  ret z
  ld c,a  ; C: Currently held

  ; If any keys were newly pressed, set the eligible keys among them
  ; as the autorepeating set.  For example, changing from Up to
  ; Up+Right sets Right as the new autorepeating set.
  ldh a,[hNewKeys]
  ld d,a  ; D: hNewKeys
  or a
  jr z,.no_restart_das
  and b
  ld [das_keys],a
  ld a,DAS_DELAY
  jr .have_das_timer
.no_restart_das:

  ; If time has expired, merge in the autorepeating set
  ld a,[das_timer]
  dec a
  jr nz,.have_das_timer
  ld a,[das_keys]
  and c
  or d
  ldh [hNewKeys],a
  ld a,DAS_SPEED
.have_das_timer:
  ld [das_timer],a
  ret

SECTION "rst60", ROM0[$0060]
  push af
  ldh a, [rLY]
  ldh [hLastKeyLY], a
  pop af
  reti  ; jp joypad_handler
