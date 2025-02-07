.include "constants.inc" 
.include "header.inc"     


.segment "ZEROPAGE"

pad1: .res 1                  ; Estado actual del controlador.
curr_slot_player: .res 1      ; Índice del slot actual para el jugador (posición para nuevas cartas).
curr_slot_dealer: .res 1      ; Índice del slot actual para el dealer.
bet_tens: .res 1              ; Decenas de la apuesta actual.
bet_unis: .res 1              ; Unidades de la apuesta actual.
cash_hundreds: .res 1         ; Centenas del efectivo actual.
cash_tens: .res 1             ; Decenas del efectivo actual.
cash_unis: .res 1             ; Unidades del efectivo actual.
temp_bet: .res 1              ; Variable temporal para manejar la apuesta.
total_cash_high_byte: .res 1  ; Byte alto del efectivo total.
total_cash_low_byte: .res 1   ; Byte bajo del efectivo total.
already_drawn: .res 1         ; Indicador de si las cartas iniciales ya se han dibujado.
total_bet: .res 1             ; Cantidad total apostada.
first_start_flag: .res 1      ; Bandera para indicar si el juego ha comenzado por primera vez.
dealer_tens: .res 1           ; Decenas de los puntos totales del dealer.
dealer_units: .res 1          ; Unidades de los puntos totales del dealer.
player_tens: .res 1           ; Decenas de los puntos totales del jugador.
player_units: .res 1          ; Unidades de los puntos totales del jugador.
temp_val: .res 1              ; Valor temporal utilizado en cálculos.
temp_val_high: .res 1         ; Parte alta del valor temporal.
natural_blackjack: .res 1     ; Bandera para indicar si el jugador tiene blackjack natural.
prev_pad1: .res 1             ; Estado anterior del controlador, usado para detección de bordes.
.exportzp pad1             ; Exporta `pad1` para que sea accesible en otros módulos.
SEED: .res 3                  ; Semilla para el generador de números aleatorios.
cards_paced: .res 52          ; Marcadores para indicar si cada carta ha sido usada (52 cartas).
mod_result: .res 1            ; Resultado de calcular el valor de la carta (módulo 13).
placecard_value: .res 1       ; Valor de la carta colocada.
curr_val_placecards_dealer: .res 1 ; Valor acumulado actual de las cartas del dealer.
total_val_cards_dealer: .res 1 ; Valor total de las cartas del dealer.
curr_val_placecards_player: .res 1 ; Valor acumulado actual de las cartas del jugador.
total_val_cards_player: .res 1 ; Valor total de las cartas del jugador.
player_end_turn: .res 1       ; Indicador de que el turno del jugador terminó.
dealer_timer: .res 1          ; Temporizador para gestionar las acciones del dealer.
draw_flag: .res 1             ; Bandera para indicar si se debe dibujar una carta.
;Bonus Variables:
hole_card_x: .res 1
hole_card_y: .res 1
hole_card_dir: .res 1
animation_flag: .res 1
hole_card_dir_y: .res 1
.exportzp hole_card_x, hole_card_y

playerside_hole_card: .res 1
dealerside_hole_card: .res 1
  

.segment "CODE"

; Interrupción de IRQ (no utilizada en este caso).
.proc irq_handler
  RTI ; Retorna de la interrupción IRQ.
.endproc


.import read_controller1 ; Importa rutina para leer el estado del control_1.



.proc nmi_handler ; Interrupción NMI: se ejecuta en cada cuadro (60 Hz).
  
 
  
  ; Verifica si el turno del jugador terminó.
  LDA player_end_turn     ; Carga el indicador de fin del turno del jugador.
  CMP #$01                ; Compara con 1 (turno terminado).
  BCC :+                  ; Si el turno no terminó (player_end_turn < 1), salta al siguiente bloque.

  ; Acciones del dealer si el turno del jugador terminó.
  INC dealer_timer        ; Incrementa el temporizador del dealer.

  JSR Dealer_turn         ; Llama a la rutina que maneja el turno del dealer.
  :

  ; Comprueba condiciones de victoria o derrota del jugador.
  JSR Check_if_WinGame    ; Verifica si el jugador ganó.
  JSR Check_if_LossGame   ; Verifica si el jugador perdió.

  ; Actualiza el estado del controlador.
  JSR read_controller1    ; Actualiza el estado de los botones en `pad1`.

  ; Permite acciones del jugador solo si su turno no ha terminado.
  LDA player_end_turn     ; Carga el indicador de fin del turno del jugador.
  CMP #$01                ; Compara con 1.
  BCS :+                  ; Si el turno terminó (player_end_turn >= 1), salta al siguiente bloque.
  
  ; Manejo de los botones A y B.
  JSR PressAForCard       ; Maneja el botón A para tomar una carta.
  JSR PressBForCard       ; Maneja el botón B para otras acciones (como plantarse).

  ; Manejo de apuestas, solo si no se han dibujado las cartas iniciales.
  LDA already_drawn       ; Verifica si las cartas iniciales ya se han dibujado.
  CMP #$00                ; Compara con 0.
  BNE :+                  ; Si las cartas ya se dibujaron (already_drawn ≠ 0), salta al siguiente bloque.
  JSR CheckIncreaseBet    ; Verifica si el botón UP se presionó para aumentar la apuesta.
  JSR CheckDecreaseBet    ; Verifica si el botón DOWN se presionó para reducir la apuesta.

  :

  ; Reinicio de la mesa o inicio del juego.
  JSR CheckResetTable     ; Verifica si el botón SELECT se presionó para reiniciar el juego.
  JSR Start_Game          ; Verifica si el botón START se presionó para comenzar el juego.

  ; Guarda el estado del controlador actual para detección de bordes.
  LDA pad1                ; Carga el estado actual del controlador.
  STA prev_pad1           ; Guarda el estado en `prev_pad1` para detectar bordes (transiciones de botones).

  ; Configuración del buffer de sprites y sincronización de desplazamiento.
  LDA #$00                ; Carga 0 en el acumulador.
  STA OAMADDR             ; Reinicia el buffer de sprites.
  LDA #$02                ; Carga la página de sprites.
  STA OAMDMA              ; Copia los datos de sprite desde la RAM al buffer de la PPU.
  
  LDA animation_flag
  CMP #$01
  BCC :+
  ; update tiles *after* DMA transfer
  JSR update_animate
  JSR DrawAnimatedCard
  
  :
  
  LDA #$00                ; Reinicia desplazamientos.
  STA $2005               ; Resetea el desplazamiento horizontal.
  STA $2005               ; Resetea el desplazamiento vertical.



  ; Retorno de la interrupción.
  RTI                     ; Retorna de la interrupción NMI.
.endproc



.import reset_handler   ; Importa rutina de inicialización (reset).
.export main            ; Exporta la rutina principal.


.proc main              ; Rutina principal: inicializa el juego.

  ; Initialize the random number generator seed
  LDA #$30      ; Arbitrary non-zero seed value
  STA SEED

  ;Bonus Initialize X and Y coordinates to animation HoleCard
  LDA #$96
  STA hole_card_x
  LDA #$26
  STA hole_card_y

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

vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000  ; turn on NMIs, use pattern table 1
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

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
STA total_cash_high_byte
STA total_cash_low_byte

STA first_start_flag
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
  LDA hole_card_tiles, X        ; Load a byte from the `sprites` table using the current value of X as the index.
  STA $0260, Y          ; Store the loaded byte into the OAM memory at the position indexed by Y.
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
.proc PlaceCard ; Rutina para colocar una carta en un slot específico.
                ; Params: SLOT_IDX($01) -> Índice del slot para la carta.
                ;         CARD_IDX($02) -> Índice de la carta (0-51).
                ;         Temps: $03, $04, $05, $06 -> Variables temporales para cálculos.

; Obtener el valor de la carta según su índice.
JSR LoadCardIndex_Value   ; Llama a la subrutina que calcula el valor de la carta (índice % 13).
LDX mod_result            ; Carga el residuo (resultado de índice % 13) en X.
LDA card_val, X           ; Usa el residuo para buscar el valor real de la carta (1-11 para A, 2, ..., K).
STA placecard_value       ; Almacena el valor de la carta en `placecard_value`.

; Marcar la carta como usada.
LDX $02                   ; Carga el índice de la carta en X.
LDA #$01                  ; Establece la carta como "usada".
STA cards_paced, X        ; Marca la carta como colocada en `cards_paced`.

; Calcular la posición del slot (SLOT_IDX * 12).
LDA #$0C                  ; Multiplicador para el cálculo (12).
LDY $01                   ; Carga el índice del slot (`SLOT_IDX`).
JSR mul8                  ; Llama a la rutina para multiplicar 8 bits.
STA $04                   ; Guarda el resultado alto (HI) en $04.
LDX $00                   ; Guarda el resultado bajo (LO) en $03.
STX $03

; Calcular la posición de la carta (CARD_IDX * 6).
LDA #$06                  ; Multiplicador para el cálculo (6).
LDY $02                   ; Carga el índice de la carta (`CARD_IDX`).
JSR mul8                  ; Llama a la rutina para multiplicar 8 bits.
STA $06                   ; Guarda el resultado alto (HI) en $06.
LDX $00                   ; Guarda el resultado bajo (LO) en $05.
STX $05

; Verificar si hay un overflow.
CMP #$00                  ; Compara con 0.
BNE mid_overflow          ; Si hay desbordamiento, salta a `mid_overflow`.

LDA #$00

; Configurar la dirección de la PPU para la esquina superior izquierda del slot.
LDX $03                   ; Carga el valor bajo (LO) del cálculo de slot.
LDA PPUSTATUS             ; Reinicia el latch de direcciones de la PPU.
LDA cards_positions, X    ; Obtiene el byte alto de la posición de la carta.
STA PPUADDR               ; Establece la dirección alta en la PPU.
LDA cards_positions + 1, X ; Obtiene el byte bajo de la posición de la carta.
STA PPUADDR               ; Establece la dirección baja en la PPU.

; Cargar los datos de tiles correspondientes a la carta.
LDX $05                   ; Carga el valor bajo (LO) del cálculo de carta.
LDA cards_slots, X        ; Carga los datos de tiles de la carta.
STA PPUDATA               ; Almacena en la PPU.

; Configurar y cargar los datos para la esquina superior derecha.
LDX $03
LDA PPUSTATUS
LDA cards_positions + 2, X
STA PPUADDR
LDA cards_positions + 3, X
STA PPUADDR

LDX $05
LDA cards_slots + 1, X
STA PPUDATA

; Configurar y cargar los datos para la esquina inferior izquierda. (Middle Left)
LDX $03
LDA PPUSTATUS
LDA cards_positions + 4, X
STA PPUADDR
LDA cards_positions + 5, X
STA PPUADDR

LDX $05
LDA cards_slots + 2, X
STA PPUDATA

; Configurar y cargar los datos para la esquina inferior derecha. (Middle Right)
LDX $03
LDA PPUSTATUS
LDA cards_positions + 6, X
STA PPUADDR
LDA cards_positions + 7, X
STA PPUADDR

LDX $05
LDA cards_slots + 3, X
STA PPUDATA

JMP skip                  ; Salta al final de esta sección para evitar procesamiento adicional.

; Manejo de desbordamiento (datos de carta > 256).
mid_overflow:
LDA #$00                  ; Reinicia el acumulador.
CMP #$00                  ; Compara con 0.
BEQ overflow              ; Si es igual, salta al manejo de desbordamiento.

skip:
; Cargar los datos para la esquina inferior izquierda.
LDX $03
LDA PPUSTATUS
LDA cards_positions + 8, X
STA PPUADDR
LDA cards_positions + 9, X
STA PPUADDR

LDX $05
LDA cards_slots + 4, X
STA PPUDATA

; Cargar los datos para la esquina inferior derecha.
LDX $03
LDA PPUSTATUS
LDA cards_positions + 10, X
STA PPUADDR
LDA cards_positions + 11, X
STA PPUADDR

LDX $05
LDA cards_slots + 5, X
STA PPUDATA
JMP done                  ; Salta al final de la rutina.

overflow:
; Configurar la dirección de la PPU para manejar desbordamientos.
LDX $03
LDA PPUSTATUS
LDA cards_positions, X    ; Dirección alta.
STA PPUADDR
LDA cards_positions + 1, X ; Dirección baja.
STA PPUADDR

; Cargar datos de tiles con ajuste por desbordamiento.
LDX $05
LDA cards_slots + 256, X
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



;; Random number generator 
.proc GenerateRandom 

  LDY #$08            ; Inicializa el contador de bits en 8 (procesará 8 bits en total).
  LDA SEED + 0        ; Carga el primer byte de la semilla actual en el acumulador (A).

:                     ; Etiqueta para el inicio del ciclo de procesamiento de bits.
  ASL                 ; Desplaza los bits en el acumulador un lugar a la izquierda.
                       ; El bit más significativo pasa al carry.

  ROL SEED + 1        ; Desplaza los bits del segundo byte de la semilla hacia la izquierda.
                       ; Incluye el bit del carry del desplazamiento anterior.

  ROL SEED + 2        ; Desplaza los bits del tercer byte de la semilla hacia la izquierda.
                       ; También incluye el bit del carry.

  BCC :+              ; Si no hay carry (desbordamiento), salta a la siguiente instrucción.
  EOR #$1B            ; Si hubo carry, realiza una operación XOR con el valor constante $1B.
                       ; Esto introduce mayor aleatoriedad en la semilla.

:                     ; Etiqueta para continuar el ciclo.
  DEY                 ; Decrementa el contador Y (indica cuántos bits quedan por procesar).
  BNE :--             ; Si Y no es cero, regresa al inicio del ciclo (procesa el siguiente bit).

  STA SEED + 0        ; Guarda el nuevo valor generado en el primer byte de la semilla.
                       ; Actualiza la semilla con el nuevo número pseudoaleatorio.

  CMP #0              ; Comparación redundante (no afecta el resultado).
  RTS                 ; Retorna al programa principal.

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



.proc Dealer_turn       ; Inicio del procedimiento "Dealer_turn", que maneja el turno del dealer.

; Verificar si el temporizador del dealer alcanzó el límite para tomar una acción.
LDA dealer_timer        ; Carga el valor de la variable 'dealer_timer' en el acumulador.
CMP #$28                ; Compara el valor del acumulador con $28 (40 en decimal).
BNE done_check          ; Si los valores no son iguales, salta a la etiqueta 'done_check'.

; Verificar si el dealer alcanzó su límite de cartas.
LDA curr_slot_dealer    ; Carga el valor de 'curr_slot_dealer' (posición actual del dealer) en el acumulador.
CMP #$14                ; Compara el valor del acumulador con $14 (20 en decimal).
BEQ done_check          ; Si son iguales, salta a la etiqueta 'done_check'.

; Verificar si el dealer ya tiene 17 puntos o más.
LDA total_val_cards_dealer ; Carga el valor de 'total_val_cards_dealer' (total de puntos del dealer) en el acumulador.
CMP #$11                ; Compara el valor con $11 (17 en decimal).
BCS finish_turn          ; Si el valor en el acumulador es mayor o igual a $11, salta a 'done_check'.

LDA #01
STA animation_flag
STA dealerside_hole_card

LDA #%00000110  ; turn off screen
STA PPUMASK
LDA #%00010000  ; turn off NMIs
STA PPUCTRL

JSR Draw_Dealer_Card    ; Llama a la subrutina 'Draw_Dealer_Card' para que el dealer tome una carta.

vblankwait1:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait1

  LDA #%10010000  ; turn on NMIs, use pattern table 1
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

; Reiniciar el temporizador del dealer después de tomar una carta.
LDA #$00                ; Carga el valor $00 (0) en el acumulador.
STA dealer_timer        ; Almacena $00 en la variable 'dealer_timer' para reiniciar el temporizador.


done_check:             ; Etiqueta a la que saltan las instrucciones condicionales cuando las condiciones se cumplen.
RTS                     ; Retorna de la subrutina.

finish_turn:
JSR CheckRoundResult
RTS


.endproc                ; Fin del procedimiento "Dealer_turn".




; Press A for dealer card.
.proc PressAForCard

LDA first_start_flag
CMP #$00
BEQ done_check

; Check if A is not pressed
LDA pad1
AND #BTN_A
BEQ done_check

; Check if A was pressed in previous frame (Edge Detection)
LDA prev_pad1
AND #BTN_A
BNE done_check

INC player_end_turn     ;STAND
DEC playerside_hole_card


done_check:
RTS
.endproc


.proc Draw_Dealer_Card ; Subrutina que maneja el proceso de dibujar una carta para el dealer.

; Generar una carta aleatoria
GenerateCard:
  JSR d51                 ; Llama a la rutina `d51` para generar un número aleatorio entre 0 y 51.
  STA $02                 ; Guarda el índice de la carta generada en la dirección $02.
  LDX $02                 ; Carga el índice de la carta en X.
  LDA cards_paced, X      ; Verifica si la carta ya fue usada (0 si no ha sido utilizada).
  CMP #$00                ; Compara el estado de la carta con 0.
  BNE GenerateCard        ; Si ya fue usada, genera otra carta.

;Store Random Card in Parameter 2 in PlaceCard
 LDY curr_slot_dealer    ; Carga el slot actual del dealer en Y.
  STY $01                 ; Almacena el slot en el parámetro $01 para la subrutina `PlaceCard`.
  CPY #$14                ; Compara el slot actual con 20 ($14, límite del dealer).
  BEQ done_check          ; Si el límite de slots se alcanzó, salta al final.

  JSR PlaceCard           ; Llama a la rutina `PlaceCard` para colocar la carta en el slot.
  INC curr_slot_dealer    ; Incrementa el índice del slot actual del dealer.

;CALCULATE TOTAL DEALER POINTS
LDA placecard_value   ; Carga el valor actual de curr_val_placecards_dealer en el acumulador

  ; Verificar si la carta es un As (darle valor de 11 o 1) y ajustar según las reglas del blackjack
  CMP #11                 ; Compara el valor de la carta con 11.
  BNE not_ace             ; Si no es un As, salta a `not_ace`.

  CLC                     ; Limpia el carry para preparar la suma.
  LDA total_val_cards_dealer ; Carga el total actual de puntos del dealer.
  ADC #11                 ; Intenta sumar 11 puntos (valor del As).
  SBC #21                 ; Resta 21 para verificar si supera 21.
  BCC not_ace             ; Si no supera 21, el valor del As es válido como 11.
  LDA #1                  ; Si supera 21, ajusta el valor del As a 1.
  STA placecard_value     ; Almacena el valor ajustado del As.

not_ace:
  LDA placecard_value     ; Carga el valor de la carta en el acumulador.
  CLC                     ; Limpia el carry para evitar interferencias en la suma.
  ADC curr_val_placecards_dealer ; Suma el valor de la carta al total actual del dealer.
  STA total_val_cards_dealer ; Actualiza el total de puntos del dealer.
  STA curr_val_placecards_dealer ; Guarda el valor acumulado en la variable temporal.


; Actualizar los puntos del dealer (decenas y unidades)
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


done_check:
RTS
.endproc




; Maneja la acción de presionar el botón B para que el jugador tome una carta.
.proc PressBForCard   ; Press B for player Card

; Verificar si el juego ya comenzó.
LDA first_start_flag      ; Carga la bandera que indica si el juego comenzó.
CMP #$00                  ; Compara con 0.
BEQ done_check            ; Si no comenzó, salta al final sin hacer nada.

; Verificar si el botón B no está siendo presionado.
LDA pad1                  ; Carga el estado actual de los botones en el controlador.
AND #BTN_B                ; Comprueba específicamente el estado del botón B.
BEQ done_check            ; Si B no está presionado, salta al final.

; Verificar si el botón B fue presionado en el frame anterior (detección de borde).
LDA prev_pad1             ; Carga el estado del controlador en el frame anterior.
AND #BTN_B                ; Verifica el estado del botón B.
BNE done_check            ; Si B estaba presionado antes, salta al final.

; Verificar si ya se han dibujado las cartas iniciales.
LDA already_drawn         ; Carga la variable que indica si las cartas iniciales ya se dibujaron.
CMP #$00                  ; Compara con 0.
BNE :+                    ; Si ya se dibujaron, salta a la etiqueta siguiente.

; Apaga la pantalla y las interrupciones mientras se reinicia la ronda de juego
LDA #%00000110  ; turn off screen
STA PPUMASK
LDA #%00010000  ; turn off NMIs
STA PPUCTRL

; Dibujar cartas iniciales (dos para el jugador y una para el dealer).
JSR Draw_Player_Card      ; Dibuja la primera carta para el jugador.
JSR Draw_Player_Card      ; Dibuja la segunda carta para el jugador.
JSR Draw_Dealer_Card      ; Dibuja la primera carta para el dealer.

vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000  ; turn on NMIs, use pattern table 1
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

; Verificar si el jugador tiene blackjack natural (21 puntos con las primeras dos cartas).
LDA total_val_cards_player ; Carga el total de puntos del jugador.
CMP #21                   ; Compara con 21.
BNE not_natural           ; Si no tiene 21, salta a `not_natural`.

INC player_end_turn       ; Finaliza automáticamente el turno del jugador.
INC natural_blackjack     ; Indica que el jugador tiene un blackjack natural.


not_natural:              ; Continúa si no hubo blackjack natural.
INC already_drawn         ; Marca que las cartas iniciales ya fueron dibujadas.
JMP done_check            ; Salta al final de la rutina.

:                         ; Etiqueta para continuar si no se dibujaron todas las cartas iniciales.

;Bonus: Animation Activate
INC animation_flag
INC playerside_hole_card

LDA #%00000110  ; turn off screen
STA PPUMASK
LDA #%00010000  ; turn off NMIs
STA PPUCTRL

JSR Draw_Player_Card      ; Dibuja una carta adicional para el jugador.

vblankwait1:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait1

  LDA #%10010000  ; turn on NMIs, use pattern table 1
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

done_check:
RTS
.endproc

.proc Draw_Player_Card

; Generar una carta aleatoria
GenerateCard:
  JSR d51                  ; Llama a la rutina `d51` para generar un número aleatorio entre 0 y 51 (representa una carta).
  STA $02                  ; Guarda el índice de la carta generada en la dirección $02.
  LDX $02                  ; Carga el índice de la carta en X.
  LDA cards_paced, X       ; Verifica si la carta ya fue usada (0 si no ha sido utilizada).
  CMP #$00                 ; Compara el estado de la carta con 0.
  BNE GenerateCard         ; Si la carta ya fue usada, genera otra carta.


; Colocar la carta en el slot del jugador
  LDY curr_slot_player     ; Carga el slot actual del jugador en Y.
  STY $01                  ; Almacena el slot en el parámetro $01 para la subrutina `PlaceCard`.
  CPY #$0A                 ; Compara el slot actual con 10 (límite de slots para el jugador).
  BEQ done_check           ; Si alcanzó el límite, salta al final.
  JSR PlaceCard            ; Llama a la rutina `PlaceCard` para colocar la carta en el slot correspondiente.

  INC curr_slot_player      ; Incrementa el índice del slot actual del jugador.


; Calcular el total de puntos del jugador
  LDA placecard_value       ; Carga el valor de la carta recién colocada.
  
  ; Verificar si la carta es un As (valor 11) y ajustar según las reglas del blackjack
  CMP #11                   ; Compara el valor de la carta con 11 (un As).
  BNE not_ace               ; Si no es un As, salta a `not_ace`.

  CLC                       ; Limpia el carry para preparar la suma.
  LDA total_val_cards_player ; Carga el total actual de puntos del jugador.
  ADC #11                   ; Intenta sumar 11 puntos (valor del As).
  SBC #21                   ; Resta 21 para verificar si supera 21.
  BCC not_ace               ; Si no supera 21, el valor del As es válido como 11.
  LDA #1                    ; Si supera 21, ajusta el valor del As a 1.
  STA placecard_value       ; Almacena el valor ajustado del As.

not_ace:
LDA placecard_value         ; Carga el valor de la carta nuevamente.
CLC                             ; Limpia el carry para evitar interferencias en la suma
ADC curr_val_placecards_player             ; Suma el valor de placecard_value al acumulador
STA total_val_cards_player      ; Guarda el resultado en total_val_cards_dealer
STA curr_val_placecards_player

; Actualizar los puntos visuales del jugador (decenas y unidades)
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
  STA player_units               ; Guarda el residuo (unidades) en player_units

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
  STY player_tens                ; Guarda el valor de las decenas en player_tens

  JSR Draw_PlayerPoints          ; Llama a la rutina para dibujar los puntos

;Verifica si automaticamen el player se pasa de 21 -PIERDE INSTANTANEAMENTE LA RONDA:
LDA total_val_cards_player
CMP #22
BCC done_check
JSR PlayerLost
;---------------------------------
done_check:
RTS
.endproc



.proc Start_Game ; Subrutina que maneja el inicio de juego, y las rondas siguientes del juego.

; Verificar si el botón START está presionado.
LDA pad1                  ; Carga el estado actual del controlador.
AND #BTN_START            ; Verifica si el botón START está presionado.
BEQ mid_done              ; Si no está presionado, salta a `mid_done`.

; Verificar si el botón START fue presionado en el frame anterior (detección de borde).
LDA prev_pad1             ; Carga el estado del controlador en el frame anterior.
AND #BTN_START            ; Verifica si START estaba presionado.
BNE mid_done              ; Si estaba presionado antes, salta a `mid_done`.

; Apagar la pantalla y deshabilitar interrupciones antes de reiniciar el juego.
LDA #%00000110            ; Configura PPUMASK para apagar la pantalla.
STA PPUMASK               ; Apaga la pantalla.
LDA #%00010000            ; Deshabilita las interrupciones NMI.
STA PPUCTRL

; Limpia el estado de las cartas colocadas
LDX #$00
clear_placed_cards:
LDA #$00
STA cards_paced, x
INX
CPX #$34
BNE clear_placed_cards

; Redraw Background and reset card and position indexes.
LDA first_start_flag
CMP #$00
BNE :+


; Inicializar valores iniciales si es la primera vez.
LDA #20                   ; Establece el dinero inicial del jugador en 20.
STA total_cash_low_byte   ; Almacena el valor en el byte bajo del efectivo total.
LDA #$02                  ; Establece las decenas del efectivo.
STA cash_tens             ; Almacena en `cash_tens`.
INC first_start_flag      ; Marca que el juego ya ha comenzado al menos una vez.



:
JMP skip2                 ; Salta para continuar con la configuración.

mid_done:                 ; Etiqueta para finalizar si START no fue presionado.
LDA #$00                  ; Código redundante.
CMP #$00                  ; Código redundante.
BEQ done_check            ; Salta al final sin hacer nada.

skip2:

; Establecer la apuesta inicial.
LDA #$05                  ; Establece la apuesta inicial en 5.
STA total_bet             ; Almacena en `total_bet`.
STA bet_unis    ;Comienza el juego con apuesta predeterminada $5.

; Reiniciar las posiciones de las cartas.
LDA #$0A                  ; Establece el slot inicial para el dealer en 10.
STA curr_slot_dealer       ; Almacena en `curr_slot_dealer`.
LDA #$00                  ; Establece el slot inicial para el jugador en 0.
STA curr_slot_player       ; Almacena en `curr_slot_player`.

; Reiniciar otros valores del juego.
LDA #$00
STA bet_tens              ; Limpia las decenas de la apuesta.
STA dealer_tens           ; Limpia las decenas de los puntos del dealer.
STA dealer_units          ; Limpia las unidades de los puntos del dealer.
STA player_tens           ; Limpia las decenas de los puntos del jugador.
STA player_units          ; Limpia las unidades de los puntos del jugador.
STA player_end_turn       ; Resetea la variable de fin de turno del jugador.
STA placecard_value       ; Limpia el valor de la carta colocada.
STA mod_result            ; Limpia el resultado del cálculo de módulo.
STA curr_val_placecards_dealer ; Limpia el valor acumulado de las cartas del dealer.
STA total_val_cards_dealer ; Limpia el total de puntos del dealer.
STA curr_val_placecards_player ; Limpia el valor acumulado de las cartas del jugador.
STA dealer_timer          ; Resetea el temporizador del dealer.
STA total_val_cards_player ; Limpia el total de puntos del jugador.
STA already_drawn         ; Marca que aún no se han dibujado cartas.
STA natural_blackjack     ; Limpia el indicador de blackjack natural.

;Bonus: Reset Animation Flag
STA animation_flag
STA playerside_hole_card
STA dealerside_hole_card

LDA #112
STA hole_card_x
LDA #24
STA hole_card_y
JSR DrawAnimatedCard

; Redibujar Background y actualizar datos en pantalla
JSR Background
JSR DrawCash      ; Dibuja el efectivo inicial
JSR DrawBet       ; Dibuja la apuesta inicial



not_natural:

vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000  ; turn on NMIs, use pattern table 1
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

done_check:
RTS
.endproc



.proc CheckResetTable
; Check if SELECT is not pressed
LDA pad1
AND #BTN_SELECT
BEQ done_check

; Check if SELECT was already pressed in previous frame (Edge Detection)
LDA prev_pad1
AND #BTN_SELECT
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
STA total_bet 
STA total_cash_high_byte
STA total_cash_low_byte
STA first_start_flag
STA bet_tens
STA bet_unis
STA cash_hundreds
STA player_end_turn

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

JSR ClearWinLossSprites

LDA #$00
STA placecard_value
STA mod_result
STA curr_slot_player
STA curr_val_placecards_dealer
STA total_val_cards_dealer
STA curr_val_placecards_player
STA total_val_cards_player
STA dealer_timer
STA already_drawn
STA player_end_turn
STA natural_blackjack


LDA #$0A
STA curr_slot_dealer
vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000  ; turn on NMIs, use pattern table 1
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

done_check:
RTS
.endproc



.proc CheckIncreaseBet

LDA pad1          ; Cargar el estado actual del controlador en A.
AND #BTN_UP       ; Comprobar si el botón UP está presionado.
BEQ done_check    ; Si no está presionado, salta al final de la subrutina.

LDA prev_pad1     ; Cargar el estado anterior del controlador.
AND #BTN_UP       ; Comprobar si UP ya estaba presionado.
BNE done_check    ; Si estaba presionado en el frame anterior, salta al final.


LDA total_bet     ; Cargar el valor de total_bet en el acumulador.
CMP #95            ; Comprobar si total_bet es igual a 0.
BEQ done_check     ; Si es igual a 0, salta al final.

;COMPARE TOTAL_BET to Total_Cash (bet <= cash)



LDA total_bet   ; Carga el valor de total_bet en el acumulador
CMP total_cash_low_byte
BCS done_check

;INCREASE BET
CLC                 ; Limpia el carry para evitar interferencias en la suma
ADC #05             ; Suma 5 al acumulador (total_bet)
STA total_bet      ; Guarda el resultado en total_bet

;Update_BET_DrawPoints
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
  STA bet_unis               ; Guarda el residuo (unidades) en bet_units

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
  STY bet_tens                ; Guarda el valor de las decenas en bet_tens

  JSR DrawBet          ; Llama a la rutina para dibujar los puntos


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

;COMPARE TOTAL_BET to 5 (bet >= 5): IF (bet == 5) --> Stop Decreasing
LDA total_bet     ; Carga el valor de la apuesta actual.
CMP #0            ; EXTRA Case -> Reset Game bet = 0. IF we don't make this compare it goes out of range (negative_values).
BEQ done_check    
CMP #05           ; Compara con 5 para asegurarse de que no sea menor.
BEQ done_check    ; Si es menor que 5, salta al final (no permite valores negativos).

;DECREASE BET  : (Else Case)
SEC               ; Activa el carry para realizar la resta.
SBC #05           ; Resta 5 al acumulador.
STA total_bet     ; Guarda el resultado en total_bet.

;Update_BET_DrawPoints
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
  STA bet_unis               ; Guarda el residuo (unidades) en bet_units

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
  STY bet_tens                ; Guarda el valor de las decenas en bet_tens

  JSR DrawBet          ; Llama a la rutina para dibujar los puntos


done_check:
RTS

.endproc

.proc CheckRoundResult
    ; Verificar si el jugador tiene un blackjack natural (21 puntos con las dos primeras cartas).
    LDA natural_blackjack       ; Carga el valor de "natural_blackjack" en el acumulador.
    CMP #$01                    ; Compara con 1 (indicando un blackjack natural).
    BCS blackjack

    ; Comprobamos primero si el jugador perdió (supera 21 puntos).
    LDA total_val_cards_player   ; Cargamos el total de puntos del jugador.
    CMP #$16                    ; Comparamos con 22 (hexadecimal: $16).
    BCC check_dealer_bust       ; Si es menor a 22, verificamos al dealer.
    JSR PlayerLost              ; Si el jugador supera 21, perdió.
    RTS                         ; Salimos de la subrutina.

check_dealer_bust:
    ; Comprobamos si el dealer perdió (supera 21 puntos).
    LDA total_val_cards_dealer   ; Cargamos el total de puntos del dealer.
    CMP #$16                     ; Comparamos con 22 (hexadecimal: $16).
    BCC compare_scores           ; Si es menor a 22, comparamos los puntos.
    JSR PlayerWin                ; Si el dealer supera 21, el jugador gana.
    RTS                          ; Salimos de la subrutina.

compare_scores:
    ; Comparamos los puntos del jugador y del dealer.
    LDA total_val_cards_player   ; Cargamos el total de puntos del jugador.
    CMP total_val_cards_dealer   ; Comparamos con los puntos del dealer.
    BEQ tie_round                ; Si los puntos son iguales, es un empate.
    BCS player_wins              ; Si el jugador tiene más, gana.
    JSR PlayerLost               ; Si el dealer tiene más, el jugador pierde.
    RTS                          ; Salimos de la subrutina.

blackjack:
    LDA total_val_cards_player   ; Cargamos el total de puntos del jugador.
    CMP total_val_cards_dealer   ; Comparamos con los puntos del dealer.
    BEQ tie_round                ; Si son iguales, es un empate.
    JSR PlayerWinBlackJackNatural ; Si el jugador tiene blackjack natural, gana.
    RTS
player_wins:
    ; Si los puntos son iguales, es un empate.
    LDA total_val_cards_player   ; Cargamos el total de puntos del jugador.
    CMP total_val_cards_dealer   ; Comparamos con los puntos del dealer.
    BEQ tie_round                ; Si son iguales, llamamos a "Tie_Round".
    JSR PlayerWin                ; De lo contrario, el jugador gana.
    RTS                          ; Salimos de la subrutina.

tie_round:
    JSR Tie_Round                ; Llamamos a la rutina de empate.
    RTS                          ; Salimos de la subrutina.

.endproc

.proc PlayerWinBlackJackNatural ; Maneja el caso en el que el jugador gana con un blackjack natural.


; Agregar 2 veces la apuesta al efectivo total:

LDA total_cash_low_byte    ; Carga el byte bajo del total de dinero del jugador en el acumulador.
CLC                        ; Limpia el "Carry" para realizar una suma segura.
ADC total_bet               ; Suma el doble de la apuesta (`temp_bet`) al acumulador.
STA total_cash_low_byte    ; Almacena el nuevo valor en el byte bajo de `total_cash_low_byte`.

LDA total_cash_high_byte   ; Carga el byte alto del total de dinero en el acumulador.
ADC #$00                   ; Suma el acarreo resultante al byte alto para completar la suma de 16 bits.
STA total_cash_high_byte   ; Almacena el resultado en el byte alto de `total_cash_high_byte`.

; Repetir el proceso para sumar nuevamente la apuesta (doble recompensa).
LDA total_cash_low_byte    ; Carga el byte bajo del total de dinero del jugador en el acumulador.
CLC                        ; Limpia el "Carry" para realizar una suma segura.
ADC total_bet               ; Suma el doble de la apuesta (`temp_bet`) al acumulador.
STA total_cash_low_byte    ; Almacena el nuevo valor en el byte bajo de `total_cash_low_byte`.

LDA total_cash_high_byte   ; Carga el byte alto del total de dinero en el acumulador.
ADC #$00                   ; Suma el acarreo resultante al byte alto para completar la suma de 16 bits.
STA total_cash_high_byte   ; Almacena el resultado en el byte alto de `total_cash_high_byte`.

; Reiniciar la apuesta del jugador
LDA #$00                   ; Carga 0 en el acumulador.
STA total_bet              ; Reinicia la cantidad apostada.
STA bet_tens               ; Reinicia las decenas de la apuesta.
STA bet_unis               ; Reinicia las unidades de la apuesta.

; Actualizar la pantalla con los valores
JSR DrawBet                ; Llama a la rutina para redibujar la apuesta en la pantalla.
JSR UpdateCash             ; Llama a la rutina para actualizar el efectivo mostrado en pantalla.

RTS
.endproc



.proc PlayerWin            ; Inicio del procedimiento "PlayerWin", que se ejecuta cuando el jugador gana.

; Agregar la cantidad de la apuesta al efectivo total del jugador.
LDA total_cash_low_byte    ; Carga el byte bajo del total de dinero del jugador en el acumulador.
CLC                        ; Limpia el "Carry" para realizar una suma segura.
ADC total_bet               ; Suma la apuesta (`temp_bet`) al acumulador.
STA total_cash_low_byte    ; Almacena el nuevo valor en el byte bajo de `total_cash_low_byte`.

LDA total_cash_high_byte   ; Carga el byte alto del total de dinero en el acumulador.
ADC #$00                   ; Suma el acarreo resultante al byte alto para completar la suma de 16 bits.
STA total_cash_high_byte   ; Almacena el resultado en el byte alto de `total_cash_high_byte`.

; Reiniciar la apuesta después de la victoria
LDA #$00                   ; Carga $00 (0) en el acumulador.
STA total_bet              ; Establece la apuesta actual a 0 (ya que el jugador ganó y la apuesta se liquida).
STA bet_tens               ; Establece la representación en decenas de la apuesta a 0.
STA bet_unis               ; Establece la representación en unidades de la apuesta a 0.

; Actualizar los valores mostrados en pantalla.
JSR DrawBet                ; Llama a la subrutina `DrawBet` para actualizar visualmente el valor de la apuesta.
JSR UpdateCash             ; Llama a la subrutina `UpdateCash` para actualizar visualmente el total de dinero del jugador.


.endproc                   ; Fin del procedimiento "PlayerWin".


.proc PlayerLost          ; Inicio del procedimiento "PlayerLost", que se ejecuta cuando el jugador pierde.

; Subtract bet from total cash and update cash and bet display
LDA total_cash_low_byte   ; Carga el byte bajo del total de dinero del jugador en el acumulador.
SEC                       ; Activa el "Carry" para realizar una resta segura.
SBC total_bet             ; Resta la cantidad apostada (`total_bet`) del acumulador.
STA total_cash_low_byte   ; Almacena el resultado (nuevo total de dinero) en el byte bajo de `total_cash_low_byte`.

SBC #$00                  ; Realiza una resta adicional con el byte alto del total de dinero, propagando el acarreo si es necesario.
STA total_cash_high_byte  ; Almacena el resultado en el byte alto de `total_cash_high_byte`.

LDA #$00                  ; Carga $00 (0) en el acumulador.
STA total_bet             ; Establece la cantidad apostada a 0 (la apuesta se pierde, así que se reinicia).
STA bet_tens              ; Establece la representación en decenas de la apuesta a 0.
STA bet_unis              ; Establece la representación en unidades de la apuesta a 0.

JSR DrawBet               ; Llama a la subrutina `DrawBet` para actualizar visualmente el valor de la apuesta.

JSR UpdateCash            ; Llama a la subrutina `UpdateCash` para actualizar visualmente el total de dinero restante del jugador.

.endproc                  ; Fin del procedimiento "PlayerLost".

.proc Tie_Round
LDA #$00                  ; Carga $00 (0) en el acumulador.
STA total_bet             ; Establece la cantidad apostada a 0 (la apuesta se pierde, así que se reinicia).
STA bet_tens              ; Establece la representación en decenas de la apuesta a 0.
STA bet_unis              ; Establece la representación en unidades de la apuesta a 0.

JSR DrawBet               ; Llama a la subrutina `DrawBet` para actualizar visualmente el valor de la apuesta.

.endproc


.proc UpdateCash ; Subrutina para calcular y descomponer el total de efectivo en centenas, decenas y unidades.

; Calcula centenas, decenas y unidades de un número de 16 bits

; === Combinar el número de 16 bits ===
  LDA total_cash_high_byte      ; Carga el byte bajo del total de efectivo en el acumulador.
  STA temp_val_high            ; Almacena el byte bajo temporalmente en `temp_val_high`.
  LDA total_cash_low_byte      ; Carga nuevamente el byte bajo.
  STA temp_val                 ; Almacena en `temp_val` para usarlo en los cálculos.            

; === Calcular Centenas ===
  LDA temp_val              ; Carga el byte bajo
  LDY temp_val_high             ; Carga el byte alto
  LDX #0                         ; Inicializa el contador de centenas en X

centenas_loop:
  LDA temp_val              ; Carga el byte bajo
  CMP #100                       ; Compara el acumulador con 100
  BCC centenas_done              ; Si A < 100, salimos (ya no hay centenas)
  SEC                            ; Activa el flag de resta
  SBC #100                       ; Resta 100 del byte bajo
  BCS skip_high_decrement        ; Si no hubo acarreo, no necesitas restar del byte alto
  DEC temp_val_high             ; Decrementa el byte alto si hubo acarreo
skip_high_decrement:
  STA temp_val              ; Guarda el resultado del byte bajo
  INX                            ; Incrementa el contador de centenas
  JMP centenas_loop              ; Repite el bucle

centenas_done:
  STX cash_hundreds               ; Guarda las centenas en bet_hundreds

; === Calcular Decenas ===
  LDA temp_val              ; Carga el byte bajo actualizado
  LDY #0                         ; Inicializa el contador de decenas

decenas_loop:
  CMP #10                        ; Compara el acumulador con 10
  BCC decenas_done               ; Si A < 10, salimos (ya no hay decenas)
  SEC                            ; Activa el flag de resta
  SBC #10                        ; Resta 10 del byte bajo
  INY                            ; Incrementa el contador de decenas
  JMP decenas_loop               ; Repite el bucle

decenas_done:
  STY cash_tens                   ; Guarda las decenas en bet_tens

; === Calcular Unidades ===
  STA cash_unis                   ; Lo que queda en A son las unidades
  JSR DrawCash                    ; Llama a la rutina para dibujar los valores

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


.proc Draw_WinGame
;G
LDA #$90 ; Y-coord
STA $0224
LDA #$31 ; Tile Index
STA $0225
LDA #$00 ; Pallete
STA $0226
LDA #$58 ; X-coord
STA $0227
;A
LDA #$90 ; Y-coord
STA $0228
LDA #$05 ; Tile Index
STA $0229
LDA #$00 ; Pallete
STA $022A
LDA #$60 ; X-coord
STA $022B
;M
LDA #$90 ; Y-coord
STA $022C
LDA #$03 ; Tile Index
STA $022D
LDA #$00 ; Pallete
STA $022E
LDA #$68 ; X-coord
STA $022F
;E
LDA #$90 ; Y-coord
STA $0230
LDA #$32 ; Tile Index
STA $0231
LDA #$00 ; Pallete
STA $0232
LDA #$70 ; X-coord
STA $0233

;W
LDA #$90 ; Y-coord
STA $0234
LDA #$04 ; Tile Index --> W
STA $0235
LDA #$00 ; Pallete
STA $0236
LDA #$7F ; X-coord
STA $0237
;I
LDA #$90 ; Y-coord
STA $0238
LDA #$06 ; Tile Index --> I
STA $0239
LDA #$00 ; Pallete
STA $023A
LDA #$88 ; X-coord
STA $023B
;N
LDA #$90 ; Y-coord
STA $023C
LDA #$0B ; Tile Index --> N
STA $023D
LDA #$00 ; Pallete
STA $023E
LDA #$91 ; X-coord
STA $023F

.endproc


.proc Draw_LossGame
;G
LDA #$90 ; Y-coord
STA $0240
LDA #$31 ; Tile Index
STA $0241
LDA #$00 ; Pallete
STA $0242
LDA #$58 ; X-coord
STA $0243
;A
LDA #$90 ; Y-coord
STA $0244
LDA #$05 ; Tile Index
STA $0245
LDA #$00 ; Pallete
STA $0246
LDA #$60 ; X-coord
STA $0247
;M
LDA #$90 ; Y-coord
STA $0248
LDA #$03 ; Tile Index
STA $0249
LDA #$00 ; Pallete
STA $024A
LDA #$68 ; X-coord
STA $024B
;E
LDA #$90 ; Y-coord
STA $024C
LDA #$32 ; Tile Index
STA $024D
LDA #$00 ; Pallete
STA $024E
LDA #$70 ; X-coord
STA $024F

;L
LDA #$90 ; Y-coord
STA $0250
LDA #$07 ; Tile Index
STA $0251
LDA #$00 ; Pallete
STA $0252
LDA #$7F ; X-coord
STA $0253
;O
LDA #$90 ; Y-coord
STA $0254
LDA #$08 ; Tile Index
STA $0255
LDA #$00 ; Pallete
STA $0256
LDA #$88 ; X-coord
STA $0257
;S
LDA #$90 ; Y-coord
STA $0258
LDA #$0D ; Tile Index
STA $0259
LDA #$00 ; Pallete
STA $025A
LDA #$91 ; X-coord
STA $025B
;S
LDA #$90 ; Y-coord
STA $025C
LDA #$0D ; Tile Index
STA $025D
LDA #$00 ; Pallete
STA $025E
LDA #$99 ; X-coord
STA $025F

.endproc

.proc Check_if_WinGame
  ; Subrutina para verificar si el jugador ha ganado (tiene exactamente 1000 de efectivo).
  LDA total_cash_high_byte   ; Carga el byte alto de `total_cash` en el acumulador.
  CLC
  CMP #$03                  ; Compara el byte alto con $03 (1000 en hexadecimal).
  BCC done_check            ; Si no es igual, salta a `done_check` (no ha ganado).
  
  LDA total_cash_low_byte    ; Carga el byte bajo de `total_cash` en el acumulador.
  CLC
  CMP #$E8                  ; Compara el byte bajo con $E8 (resto de 1000 en hexadecimal).
  BCC done_check            ; Si no es igual, salta a `done_check` (no ha ganado).

  JSR Draw_WinGame          ; Si ambos bytes coinciden con 1000, llama a `Draw_WinGame` 
                            ; para mostrar la pantalla de victoria.

done_check:
  RTS                        ; Retorna al llamador.

.endproc


.proc Check_if_LossGame
  ; Subrutina para verificar si el jugador ha perdido (se quedó sin dinero).
  LDA first_start_flag
  CMP #$00
  BEQ done_check


  LDA total_cash_high_byte   ; Carga el byte alto de la variable `total_cash` en el acumulador.
  CMP #0                     ; Compara el valor con 0.
  BNE done_check             ; Si no es igual a 0 (aún hay dinero), salta a la etiqueta `done_check`.

  LDA total_cash_low_byte    ; Si el byte alto es 0, carga el byte bajo de `total_cash` en el acumulador.
  CMP #0                     ; Compara el byte bajo con 0.
  BNE done_check             ; Si no es igual a 0 (aún hay dinero), salta a la etiqueta `done_check`.

  JSR Draw_LossGame          ; Si ambos bytes (alto y bajo) son 0, llama a la subrutina `Draw_LossGame` 
                             ; para dibujar la pantalla de pérdida.

done_check:
  RTS                        ; Retorna al llamador, ya sea porque hay dinero o se terminó de ejecutar la
                             ; pantalla de pérdida.

.endproc



.proc ClearWinLossSprites
    ;G
LDA #$F1 ; Y-coord
STA $0240

;A
LDA #$F2 ; Y-coord
STA $0244

;M
LDA #$F3 ; Y-coord
STA $0248

;E
LDA #$F4 ; Y-coord
STA $024C


;L
LDA #$F5 ; Y-coord
STA $0250

;O
LDA #$F6 ; Y-coord
STA $0254

;S
LDA #$F6 ; Y-coord
STA $0258

;S
LDA #$F6 ; Y-coord
STA $025C



LDA #$F4 ; Y-coord
STA $0228
LDA #$F4 ; Y-coord
STA $022C
LDA #$F4 ; Y-coord
STA $0230
LDA #$F4 ; Y-coord
STA $0234
LDA #$F4 ; Y-coord
STA $0238
LDA #$F4 ; Y-coord
STA $023C
    RTS
.endproc





;Bonus Animation Hole Card:
.proc update_animate

  ; --- Verificación del límite izquierdo ---
  check_horizontal:
  LDX $01
  LDA hole_card_x        ; Carga la posición actual en X.
  CMP slot_x_positions,X               ; Compara con el borde izquierdo ($10).
  BEQ check_vertical     ; Si no es igual, continúa con el movimiento vertical.

  playercall_x:
  LDA playerside_hole_card
  CMP #01
  BNE dealercall_x
  CLC
  LDX curr_slot_player
  LDA hole_card_x        ; Carga la posición actual en X.
  SBC slot_animation_steps_x,X
  STA hole_card_x
  JMP check_vertical

  dealercall_x:
  LDA dealerside_hole_card
  CMP #01
  BNE playercall_x
  CLC
  LDX curr_slot_dealer
  LDA hole_card_x        ; Carga la posición actual en X.
  ADC slot_animation_steps_x,X
  STA hole_card_x

  ; Si alcanzamos el borde izquierdo:
  
check_vertical:
  ; --- Verificación del límite inferior ---
  LDX $01
  LDA hole_card_y        ; Carga la posición actual en Y.
  CMP slot_y_positions,X               ; Compara con el borde inferior ($d0).
  BCS finish     ; Si es menor que $d0, salta al movimiento diagonal.
  CLC  
  LDA hole_card_y        ; Carga la posición actual en Y.
  ADC slot_animation_steps_y,X               ; Incrementa la posición en Y (mueve hacia abajo).
  STA hole_card_y        ; Guarda la nueva posición en Y.



exit_subroutine:
  ; Todo listo, retorna del subprograma.
  RTS                    ; Retorna del subprograma.

finish:
  LDA #$00
  STA animation_flag
  STA playerside_hole_card
  STA dealerside_hole_card

  LDA #112
  STA hole_card_x
  LDA #24
  STA hole_card_y
  JSR DrawAnimatedCard

  RTS

.endproc


.proc DrawAnimatedCard
LDA hole_card_y
STA $0278
LDA #$53
STA $0279
LDA #$00
STA $027A
LDA hole_card_x
STA $027B
CLC
LDA hole_card_y
STA $027C
LDA #$54
STA $027D
LDA #$00
STA $027E
LDA hole_card_x
ADC #$08
STA $027F
CLC
LDA hole_card_y
ADC #$08
STA $0280
LDA #$55
STA $0281
LDA #$00
STA $0282
LDA hole_card_x
STA $0283
CLC
LDA hole_card_y
ADC #$08
STA $0284
LDA #$56
STA $0285
LDA #$00
STA $0286
LDA hole_card_x
ADC #$08
STA $0287
CLC
LDA hole_card_y
ADC #$10
STA $0288
LDA #$57
STA $0289
LDA #$00
STA $028A
LDA hole_card_x
STA $028B
CLC
LDA hole_card_y
ADC #$10
STA $028C
LDA #$58
STA $028D
LDA #$00
STA $028E
LDA hole_card_x
ADC #$08
STA $028F

RTS
.endproc
;---------------------------------------------


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
;index:0  1  2  3  4  5  6  7  8  9   10  11  12

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

hole_card_tiles:
;Draw Hole Card
.byte 24, $53, $00, 112  ; Top Left
.byte 24, $54, $00, 120  ; Top Right
.byte 32, $55, $00, 112  ; Middle Left
.byte 32, $56, $00, 120  ; Middle Right
.byte 40, $57, $00, 112  ; Bottom Left
.byte 40, $58, $00, 120  ; Bottom Right

slot_y_positions:
.byte 40,40, 74,74, 104,104, 140,140, 172,172
.byte 40,40, 74,74, 104,104, 140,140, 172,172

slot_x_positions:
.byte 44, 44, 44, 44, 44, 44, 44, 44, 44, 44
.byte 216, 216, 216, 216, 216, 216, 216, 216, 216, 216

slot_animation_steps_x:
;      0   1
.byte 6,6
;      2   3
.byte 5,5
;      4   5
.byte 5,5
;      6   7
.byte 8,8
;      8   9
.byte 5,5
;      10  11
.byte 6,6
;      12  13
.byte 5,5
;      14  15
.byte 5,5
;      16  17
.byte 5,5
;      18  19
.byte 5,5

slot_animation_steps_y:
;      0   1
.byte 3,3
;      2   3
.byte 4,4
;      4   5
.byte 4,4
;      6   7
.byte 6,6
;      8   9
.byte 6,6
;      10  11
.byte 7,7
;      12  13
.byte 8,8
;      14  15
.byte 8,8
;      16  17
.byte 8,8
;      18  19
.byte 8,8




.segment "CHR"
.incbin "blackjack_tiles.chr"

