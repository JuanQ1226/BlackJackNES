.include "constants.inc" 
.include "header.inc"     


.segment "ZEROPAGE"

  pad1: .res 1               ; Estado actual del controlador.
  curr_slot_player: .res 1   ; Índice del slot actual para el jugador.
  curr_slot_dealer: .res 1   ; Índice del slot actual para el dealer.
  bet_tens: .res 1           ; Decenas de la apuesta.
  bet_unis: .res 1           ; Unidades de la apuesta.
  cash_hundreds: .res 1      ; Centena del efectivo.
  cash_tens: .res 1          ; Decenas del efectivo.
  cash_unis: .res 1          ; Unidades del efectivo.

  dealer_tens: .res 1
  dealer_units: .res 1
  player_tens: .res 1
  player_units: .res 1
  temp_val: .res 1

  prev_pad1: .res 1          ; Estado anterior del controlador para detectar pulsaciones únicas.
  .exportzp pad1             ; Exporta `pad1` para que sea accesible en otros módulos.
  SEED: .res 3
  cards_paced: .res 52

  mod_result: .res 1
  placecard_value: .res 1
  
  curr_val_placecards_dealer : .res 1
  total_val_cards_dealer : .res 1

  curr_val_placecards_player : .res 1
  total_val_cards_player : .res 1
  


.segment "CODE"

; Interrupción de IRQ (no utilizada en este caso).
.proc irq_handler
  RTI ; Retorna de la interrupción IRQ.
.endproc


.import read_controller1 ; Importa rutina para leer el estado del control_1.



.proc nmi_handler ; Interrupción NMI: se ejecuta en cada cuadro (60 Hz).
 
  JSR read_controller1    ; Update controller State Each Frame.
  JSR PressAForCard       ; Check for A button press to place a card for the player.
  JSR PressBForCard       ; Check for B button press to place a card for the dealer.
  JSR CheckIncreaseBet    ; Comprueba si se presionó UP para aumentar la apuesta.
  JSR CheckDecreaseBet    ; Comprueba si se presionó DOWN para reducir la apuesta.
  JSR CheckResetTable     ; Check if Start is pressed to reset the table.

  ; Save current frame's button presses to prev_pad1 for edge detection
  LDA pad1
  STA prev_pad1

  ; Buffering para los sprites y desplazamiento (se configura cada cuadro).
  LDA #$00
  STA OAMADDR   ; Reinicia el buffer de sprites.
  LDA #$02
  STA OAMDMA    ; Copia los datos de sprite a la memoria de la PPU.
	LDA #$00
	STA $2005     ; Resetea el desplazamiento horizontal.
	STA $2005     ; Resetea el desplazamiento vertical.

  RTI           ; Retorna de la interrupción NMI.
.endproc


.import reset_handler   ; Importa rutina de inicialización (reset).
.export main            ; Exporta la rutina principal.


.proc main              ; Rutina principal: inicializa el juego.

  ; Initialize the random number generator seed
  LDA #$30      ; Arbitrary non-zero seed value
  STA SEED

  ; write a Palette in Direction $3F00-3F1F:
  LDX PPUSTATUS         ; Lee el estado de la PPU para reiniciar el latch de direcciones.
  LDX #$3f              ; Configura la dirección de la paleta en la PPU.
  STX PPUADDR           ; Escribe el byte alto de la dirección.
  LDX #$00              ; Configura el byte bajo de la dirección.
  STX PPUADDR           ; Escribe el byte bajo de la dirección.
load_palettes:
  LDA palettes,X        ; Carga el color de la paleta.
  STA PPUDATA           ; Escribe el color en la PPU.
  INX                   ; Incrementa el índice.
  CPX #$20              ; Comprueba si ya se cargaron 32 colores.
  BNE load_palettes     ; Repite hasta que se carguen todos los colores.


JSR Background          ; Call Background Subroutine for draw Table
JSR Draw_HoleCard       ; Call Draw_HoleCard Subrotine for Draw Hole Card as Sprites



; Setup Card and Slot Counters for player and dealer.
; Inicializa los contadores para las cartas y posiciones de jugador y dealer.

LDA #$00              ; Slot inicial del jugador.
STA curr_slot_player

STA placecard_value   ;inicializar en 0.
STA curr_val_placecards_dealer ; inicializar valor en 0.
STA curr_val_placecards_player ; init en 0.


LDA #$0A              ; Slot inicial del dealer.
STA curr_slot_dealer


; Initialize Bet and Cash digits
LDA #$00
STA bet_tens
STA bet_unis
STA cash_hundreds
STA cash_tens
STA cash_unis
STA player_tens
STA player_units
STA dealer_tens
STA dealer_units


JSR DrawBet         ; Dibuja la apuesta inicial en la pantalla.
JSR DrawCash        ; Dibuja el efectivo inicial en la pantalla.

forever:
  JMP forever
.endproc

.proc Draw_HoleCard     ; Start of the routine to draw the hole card.
LDX #$00                ; Initialize X register to 0. This will be used as the index for the sprite data table.
LDY #$00                ; Initialize Y register to 0. This will be used as the index for writing to OAM memory.

load_sprites:           
  LDA sprites, X        ; Load a byte from the `sprites` table using the current value of X as the index.
  STA $0224, Y          ; Store the loaded byte into the OAM memory at the position indexed by Y.
  INX                   ; Increment the X register to point to the next byte in the `sprites` table.
  INY                   ; Increment the Y register to point to the next position in the OAM memory.

  CPX #(6*4)            ; Compare X with 24 (6 sprites x 4 bytes per sprite) to check if all data has been processed.
  BNE load_sprites      ; If X is not equal to 24, continue looping to process the next byte.

  RTS                   ; Return.
.endproc                ; End of the routine.


;Create the Background Subroutine for draw Game Table
.proc Background	

load_background_table:

  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$00
  STA PPUADDR

  LDX #$00
write_table_1:
  LDA refac_table, x
  STA PPUDATA
  INX
  CPX #$00 ; [0 - 255]
  BNE write_table_1

write_table_2:
  LDA refac_table+256, x
  STA PPUDATA
  INX
  CPX #$00 ; [256 - 511]
  BNE write_table_2

write_table_3:
  LDA refac_table+512, x
  STA PPUDATA
  INX
  CPX #$00 ; [512 - 767]
  BNE write_table_3

write_table_4:
  LDA refac_table+768, x
  STA PPUDATA
  INX
  CPX #$C0 ; [768 - 959]
  BNE write_table_4

; finally, attribute table
LDA PPUSTATUS
LDA #$23
STA PPUADDR
LDA #$C0
STA PPUADDR
LDX #$00
write_attribute:
LDA refac_table+960, X
STA PPUDATA
INX
CPX #$40 ; [960 - 1,024]
BNE write_attribute

vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000  ; turn on NMIs, use pattern table 1
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

RTS			;Return 

.endproc	; Finish Background Subroutine

.proc LoadCardIndex_Value

    LDX #0          ; Inicializa el índice del residuo
    LDA $02         ; Carga el valor del card_indx en el acumulador

    ; [0-51]-Card_index_val($02) Mod 13:
mod_loop:
    CMP #13         ; Compara el valor en el acumulador con 13
    BCC mod_done    ; Si x < 13, sal del bucle
    SEC             ; Activa el flag de resta
    SBC #13         ; Resta 13 de x
    INX             ; Incrementa el residuo (puedes usarlo para depurar si es necesario)
    JMP mod_loop    ; Repite el proceso
mod_done:
    STA mod_result  ; Guarda el residuo en mod_result
    RTS             ; Retorna

.endproc


;; Draws a card taking 2 parameters: slot index, card index
; Slot Inddex corresponds to the positions of the nex layout:
; Card Slot Layout
;   P1:          PC:
; ----------------------
;| 0  1   |    10  11   |
;| 2  3   |    12  13   |
;| 4  5   |    14  15   |
;| 6  7   |    16  17   |
;| 8  9   |    18  19   |
;------------------------
.proc PlaceCard ; Params: SLOT_IDX($01), CARD_IDX($02), Temps ($03, $04, $05, $06)

;Store the placecard value 
JSR LoadCardIndex_Value
LDX mod_result       ; Carga el índice de `mod_result` en X
LDA card_val, X      ; Usa X para indexar `card_val`
STA placecard_value

; Make 
LDX $02
LDA #$01
STA cards_paced, x


; Multiply SLOT_IDX By 12 to get correct addres, low bits stored on $03, High stored on $04
LDA #$0C
LDY $01
JSR mul8
STA $04 ;HI bits of Mult
LDX $00
STX $03 ; Lo bits of Mult

; Multiply CARD_IDX By 6 to get correct address, ow bits stored on $05, High stored on $06
LDA #$06
LDY $02
JSR mul8
STA $06 ;HI bits of Mult
LDX $00
STX $05 ;Lo bits of Mult


; Check for overflow
CMP #$00
BNE mid_overflow

LDA #$00


; Set PPUADDR to the top left corner of the corresponding cards_position
LDX $03
LDA PPUSTATUS
LDA cards_positions,x ; HI Bit.
STA PPUADDR
LDA cards_positions + 1, x ; LO Bit.
STA PPUADDR

; Load tile data corresponding to the card_slot[x] into PPUDATa
LDX $05
LDA cards_slots, x
STA PPUDATA

; Same for Top right corner
LDX $03
LDA PPUSTATUS
LDA cards_positions + 2,x
STA PPUADDR
LDA cards_positions + 3, x
STA PPUADDR

LDX $05
LDA cards_slots + 1, x
STA PPUDATA

; Middle Left
LDX $03
LDA PPUSTATUS
LDA cards_positions + 4,x
STA PPUADDR
LDA cards_positions + 5, x
STA PPUADDR

LDX $05
LDA cards_slots + 2, x
STA PPUDATA

;Middle Right
LDX $03
LDA PPUSTATUS
LDA cards_positions + 6,x
STA PPUADDR
LDA cards_positions + 7, x
STA PPUADDR

LDX $05
LDA cards_slots + 3, x
STA PPUDATA

JMP skip

mid_overflow:
LDA #$00
CMP #$00
BEQ overflow


skip:
; Bottom Left
LDX $03
LDA PPUSTATUS
LDA cards_positions + 8,x
STA PPUADDR
LDA cards_positions + 9, x
STA PPUADDR

LDX $05
LDA cards_slots + 4, x
STA PPUDATA

; Bottom Right
LDX $03
LDA PPUSTATUS
LDA cards_positions + 10,x
STA PPUADDR
LDA cards_positions + 11, x
STA PPUADDR

LDX $05
LDA cards_slots + 5, x
STA PPUDATA
JMP done

overflow:
; Set PPUADDR to the top left corner of the corresponding cards_position
LDX $03
LDA PPUSTATUS
LDA cards_positions,x ; HI Bit.
STA PPUADDR
LDA cards_positions + 1, x ; LO Bit.
STA PPUADDR

; Load tile data corresponding to the card_slot[x] into PPUDATa
LDX $05
LDA cards_slots + 256, x
STA PPUDATA
; Same for Top right corner
LDX $03
LDA PPUSTATUS
LDA cards_positions + 2,x
STA PPUADDR
LDA cards_positions + 3, x
STA PPUADDR

LDX $05
LDA cards_slots + 257, x
STA PPUDATA

; Middle Left
LDX $03
LDA PPUSTATUS
LDA cards_positions + 4,x
STA PPUADDR
LDA cards_positions + 5, x
STA PPUADDR

LDX $05
LDA cards_slots + 258, x
STA PPUDATA

;Middle Right
LDX $03
LDA PPUSTATUS
LDA cards_positions + 6,x
STA PPUADDR
LDA cards_positions + 7, x
STA PPUADDR

LDX $05
LDA cards_slots + 259, x
STA PPUDATA

; Bottom Left
LDX $03
LDA PPUSTATUS
LDA cards_positions + 8,x
STA PPUADDR
LDA cards_positions + 9, x
STA PPUADDR

LDX $05
LDA cards_slots + 260, x
STA PPUDATA

; Bottom Right
LDX $03
LDA PPUSTATUS
LDA cards_positions + 10,x
STA PPUADDR
LDA cards_positions + 11, x
STA PPUADDR

LDX $05
LDA cards_slots + 261, x
STA PPUDATA


done:
RTS
.endproc



;; Random number generator ------
.proc GenerateRandom
  LDY #$08
  LDA SEED + 0
:      ; Load current seed
  ASL            ; Shift left
  ROL SEED + 1
  ROL SEED + 2
  BCC :+
  EOR #$1B    ; XOR with Seed
:
  DEY
  BNE :--
  STA SEED + 0
  CMP #0      ; Store new seed
  RTS

.endproc

.proc d51
  loop: 
  JSR GenerateRandom
  AND #%00111111
  CMP #$33
  BPL loop
  CLC
  ADC #$01
  RTS
.endproc
;------------------------------


; Press A for dealer card.
.proc PressAForCard
; Check if A is not pressed
LDA pad1
AND #BTN_A
BEQ done_check

; Check if A was pressed in previous frame (Edge Detection)
LDA prev_pad1
AND #BTN_A
BNE done_check

; Draw card
GenerateCard:
JSR d51  	  ;Generate Random Card [0-51]
STA $02
LDX $02
LDA cards_paced,X
CMP #$00
BNE GenerateCard   
              ;Store Random Card in Parameter 2 in PlaceCard
LDY curr_slot_dealer
STY $01
CPY #$14
BEQ done_check
JSR PlaceCard

INC curr_slot_dealer

;CALCULATE TOTAL DEALER POINTS
LDA placecard_value   ; Carga el valor actual de curr_val_placecards_dealer en el acumulador
CLC                             ; Limpia el carry para evitar interferencias en la suma
ADC curr_val_placecards_dealer             ; Suma el valor de placecard_value al acumulador
STA total_val_cards_dealer      ; Guarda el resultado en total_val_cards_dealer
STA curr_val_placecards_dealer

;------------Update_Dealer_DrawPoints--------------------

  LDX #0                         ; Inicializa el índice del residuo (para las unidades)
  STA temp_val                   ; Guarda el valor en una variable temporal

  ; Cargar el valor temporal y calcular mod 10 (unidades)
  LDA temp_val                   ; Carga la copia en el acumulador
mod_loop:
  CMP #10                        ; Compara el valor en el acumulador con 10
  BCC mod_done                   ; Si A < 10, sal del bucle
  SEC                            ; Activa el flag de resta
  SBC #10                        ; Resta 10 del acumulador
  INX                            ; Incrementa el residuo
  JMP mod_loop                   ; Repite el proceso
mod_done:
  STA dealer_units               ; Guarda el residuo (unidades) en dealer_units

  ; Ahora calcula las decenas
  LDA temp_val                   ; Carga el valor original nuevamente
  LDY #0                         ; Inicializa el contador de decenas
decenas_loop:
  CMP #10                        ; Compara A con 10
  BCC decenas_done               ; Si A < 10, termina el bucle
  SEC                            ; Activa el flag de resta
  SBC #10                        ; Resta 10 del acumulador
  INY                            ; Incrementa el contador de decenas
  JMP decenas_loop               ; Repite el proceso
decenas_done:
  STY dealer_tens                ; Guarda el valor de las decenas en dealer_tens

  JSR Draw_DealerPoints          ; Llama a la rutina para dibujar los puntos
;-----------------------------------------------------------------------------

done_check:
RTS
.endproc



; Press B for player Card
.proc PressBForCard
; Check if B is not pressed
LDA pad1
AND #BTN_B
BEQ done_check

; Check if B was pressed in previous frame (Edge Detection)
LDA prev_pad1
AND #BTN_B
BNE done_check

; Draw card 
GenerateCard:
JSR d51       ;Generate Random Card [0-51]
STA $02
LDX $02
LDA cards_paced,X
CMP #$00
BNE GenerateCard

LDY curr_slot_player
STY $01
CPY #$0A
BEQ done_check
JSR PlaceCard

INC curr_slot_player


;CALCULATE TOTAL Player POINTS
LDA placecard_value   ; Carga el valor actual de curr_val_placecards_dealer en el acumulador
CLC                             ; Limpia el carry para evitar interferencias en la suma
ADC curr_val_placecards_player             ; Suma el valor de placecard_value al acumulador
STA total_val_cards_player      ; Guarda el resultado en total_val_cards_dealer
STA curr_val_placecards_player

;------------Update_Dealer_DrawPoints--------------------

  LDX #0                         ; Inicializa el índice del residuo (para las unidades)
  STA temp_val                   ; Guarda el valor en una variable temporal

  ; Cargar el valor temporal y calcular mod 10 (unidades)
  LDA temp_val                   ; Carga la copia en el acumulador
mod_loop:
  CMP #10                        ; Compara el valor en el acumulador con 10
  BCC mod_done                   ; Si A < 10, sal del bucle
  SEC                            ; Activa el flag de resta
  SBC #10                        ; Resta 10 del acumulador
  INX                            ; Incrementa el residuo
  JMP mod_loop                   ; Repite el proceso
mod_done:
  STA player_units               ; Guarda el residuo (unidades) en dealer_units

  ; Ahora calcula las decenas
  LDA temp_val                   ; Carga el valor original nuevamente
  LDY #0                         ; Inicializa el contador de decenas
decenas_loop:
  CMP #10                        ; Compara A con 10
  BCC decenas_done               ; Si A < 10, termina el bucle
  SEC                            ; Activa el flag de resta
  SBC #10                        ; Resta 10 del acumulador
  INY                            ; Incrementa el contador de decenas
  JMP decenas_loop               ; Repite el proceso
decenas_done:
  STY player_tens                ; Guarda el valor de las decenas en dealer_tens

  JSR Draw_PlayerPoints          ; Llama a la rutina para dibujar los puntos
;-----------------------------------------------------------------------------


done_check:
RTS
.endproc

.proc CheckResetTable
; Check if START is not pressed
LDA pad1
AND #BTN_START
BEQ done_check

; Check if START was already pressed in previous frame (Edge Detection)
LDA prev_pad1
AND #BTN_START
BNE done_check


LDA #%00000110  ; turn off screen
STA PPUMASK
LDA #%00010000  ; turn off NMIs
STA PPUCTRL


LDX #$00
clear_placed_cards:
LDA #$00
STA cards_paced, x
INX
CPX #$34
BNE clear_placed_cards

; Redraw Background and reset card and position indexes.
JSR Background



LDA #$00
STA bet_tens
STA bet_unis
STA cash_hundreds
STA cash_tens
STA cash_unis
STA dealer_tens
STA dealer_units
STA player_tens
STA player_units

JSR DrawBet
JSR DrawCash

JSR Draw_DealerPoints
JSR Draw_PlayerPoints

LDA #$00
STA placecard_value
STA mod_result
STA curr_slot_player
STA curr_val_placecards_dealer
STA total_val_cards_dealer
STA curr_val_placecards_player
STA total_val_cards_player

LDA #$0A
STA curr_slot_dealer

done_check:
RTS
.endproc



.proc CheckIncreaseBet

LDA pad1
AND #BTN_UP
BEQ done_check

LDA prev_pad1
AND #BTN_UP
BNE done_check


LDA bet_unis
ADC #$05
CMP #$0A
BEQ add_to_tens
STA bet_unis
JMP draw


add_to_tens:

LDX bet_tens
CPX #$09
BEQ done_check
INC bet_tens
LDA #$00
STA bet_unis

draw:
JSR DrawBet

done_check:
RTS
.endproc

.proc CheckDecreaseBet

LDA pad1
AND #BTN_DOWN
BEQ done_check

LDA prev_pad1
AND #BTN_DOWN
BNE done_check


LDA bet_unis
CMP #$00
BEQ sub_to_tens
SBC #$05
STA bet_unis
JMP draw


sub_to_tens:

LDX bet_tens
CPX #$00
BEQ done_check
DEC bet_tens
LDA #$05
STA bet_unis

draw:
JSR DrawBet

done_check:
RTS
.endproc


.proc DrawBet

LDX bet_tens

LDA #$D7
STA $0200
LDA digits,x
STA $0201
LDA #$00
STA $0202
LDA #$48
STA $0203

LDX bet_unis

LDA #$D7
STA $0204
LDA digits,X
STA $0205
LDA #$00
STA $0206
LDA #$50
STA $0207


.endproc

.proc DrawCash

LDX cash_hundreds ;new hundreds

LDA #$C7
STA $0208
LDA digits,x
STA $0209
LDA #$00
STA $020A
LDA #$48
STA $020B

LDX cash_tens

LDA #$C7 ; Y-coord
STA $020C
LDA digits,X; Tile Index
STA $020D
LDA #$00; Pallete
STA $020E
LDA #$50; X-coord
STA $020F


LDX cash_unis

LDA #$C7 ; Y-coord
STA $0210
LDA digits,X; Tile Index
STA $0211
LDA #$00; Pallete
STA $0212
LDA #$58; X-coord
STA $0213

.endproc

;---------------------
.proc Draw_PlayerPoints

LDX player_tens

LDA #$18 ; Y-coord
STA $0214
LDA digits,X ; Tile Index
STA $0215
LDA #$00; Pallete
STA $0216
LDA #$30; X-coord
STA $0217

LDX player_units

LDA #$18 ; Y-coord
STA $0218
LDA digits,X ; Tile Index
STA $0219
LDA #$00 ; Pallete
STA $021A
LDA #$38 ; X-coord
STA $021B

.endproc


.proc Draw_DealerPoints

LDX dealer_tens

LDA #$18 ; Y-coord
STA $021C
LDA digits,X ; Tile Index
STA $021D
LDA #$00; Pallete
STA $021E
LDA #$C8; X-coord
STA $021F

LDX dealer_units

LDA #$18 ; Y-coord
STA $0220
LDA digits,X ; Tile Index
STA $0221
LDA #$00 ; Pallete
STA $0222
LDA #$D0 ; X-coord
STA $0223

.endproc

;;
; Multiplies two 8-bit factors to produce a 16-bit product
; in about 153 cycles.
; @param A one factor
; @param Y another factor
; @return high 8 bits in A; low 8 bits in $0000
;         Y and $0001 are trashed; X is untouched
.proc mul8
prodlo  = $0000
factor2 = $0001

  ; Factor 1 is stored in the lower bits of prodlo; the low byte of
  ; the product is stored in the upper bits.
  LSR A  ; prime the carry bit for the loop
  STA prodlo
  STY factor2
  LDA #0
  LDY #8
loop:
  ; At the start of the loop, one bit of prodlo has already been
  ; shifted out into the carry.
  BCC noadd
  CLC
  ADC factor2
noadd:
  ROR a
  ROR prodlo  ; pull another bit out for the next iteration
  DEY         ; inc/dec don't modify carry; only shifts and adds do
  BNE loop
  RTS
.endproc


.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "RODATA"

.include"refac_table.asm" ;Call the file for the backgrounds created using the NEXXT Tool
.include"cards_slots.asm" ;Call the file for the Cards created using the NEXXT Tool
.include"cards_positions.asm"

digits:
.byte $13, $14, $15, $16, $17, $18, $19, $1A, $1B, $1C, $13

card_val:
;     A   2  3  4  5  6  7  8  9  10  J   K   Q
.byte 11, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10


palettes:
; Background Palette
.byte $0f, $11, $16, $30  
.byte $0f, $11, $16, $30
.byte $0f, $27, $16, $30
.byte $0f, $11, $07, $30

; Sprite Palette 
.byte $0f, $11, $16, $30
.byte $0f, $01, $16, $30
.byte $0f, $05, $16, $30
.byte $0f, $01, $1a, $30

sprites:
;Draw Hole Card
.byte $26, $53, $00, $96  ; Top Left
.byte $26, $54, $00, $9E  ; Top Right
.byte $2C, $55, $00, $96  ; Middle Left
.byte $2C, $56, $00, $9E  ; Middle Right
.byte $34, $57, $00, $96  ; Bottom Left
.byte $34, $58, $00, $9E  ; Bottom Right

.segment "CHR"
.incbin "blackjack_tiles.chr"

