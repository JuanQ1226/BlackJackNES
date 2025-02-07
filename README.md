# Blackjack Game for the NES (6502 Assembly)
![image](https://github.com/user-attachments/assets/7164e270-12f4-4c3b-a853-4016dcb268b6)
## Compilando el codigo:

1. `ca65 game_blackjack.asm`
2. `ca65 controllers.asm`
3. `ca65 reset.asm`
4. `ca65 game_blackjack.asm && ca65 reset.asm && ca65 controllers.asm && ld65 reset.o game_blackjack.o controllers.o -C ../nes.cfg -o game_blackjack.nes`

<!-- Si el build task no corre usa este commando en la terminal:

`cl65 --verbose --target nes src.s -o src.nes` -->

## Trabajando en Sprite y Background:

La herramienta de NEXXT puede guardar sesiones que guardan la data de los sprites. En **File > Save Session**.

El file para sprties es `playingcards.nss`
