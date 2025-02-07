.include "constants.inc"

.segment "ZEROPAGE"
.importzp pad1

.segment "CODE"
.export read_controller1
.proc read_controller1
  PHP
  PHA
  TXA
  PHA

  ; write a 1, then a 0, to CONTROLLER1
  ; to latch button states
  LDA #$01
  STA CONTROLLER1
  LDA #$00
  STA CONTROLLER1

  LDA #%00000001
  STA pad1

get_buttons:
  LDA CONTROLLER1 ; Read next button's state
  LSR A           ; Shift button state right, into carry flag
  ROL pad1        ; Rotate button state from carry flag
                  ; onto right side of pad1
                  ; and leftmost 0 of pad1 into carry flag
  BCC get_buttons ; Continue until original "1" is in carry flag

  PLA
  TAX
  PLA
  PLP
  RTS
.endproc