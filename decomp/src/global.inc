  IF  !DEF(GLOBAL_INC)
DEF GLOBAL_INC EQU 1

; still haven't ported things to SECTION UNION
; http://gbdev.gg8.se/forums/viewtopic.php?pid=3176#p3176
DEF hLocals EQU $FF80
DEF locals_size EQU 16

  ENDC