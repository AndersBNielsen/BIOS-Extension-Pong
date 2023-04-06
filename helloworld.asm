cpu 8086

;=====Constants=====
VIDEORAM equ 0B800h

;=====Setup=====
section     .text align=1 ; Text section
start:
dw 0aa55h   ; Magic word for BIOS extensions
db 32       ; Number of 512 byte blocks, 32 = 16k

;=====Init RAM=====
mov ax, 2000h
mov ds, ax

mov word [ballx], 80
mov word [bally], 12
mov word [balldx], 2 ; Right
mov word [balldy], 1 ; Down
mov word [lastball], 0 ; 0,0
mov byte [flags], 0
mov byte [color], 20h
mov word [score], 0
mov byte [paddle], 12
mov byte [lastpaddle], -1

setup:
mov ah, 0 ; Function 0, set mode
mov al, 03h ; Mode 3 = 80x25, 16 colors
int 10h

mov ah, 01
mov cx, 2607h ; Hide cursor
int 10h

mov bx, 0 ; Disable blinking
mov ax, 1003h
int 10h

mov ax, VIDEORAM ; Setup ES as VRAM segment
mov es, ax

;Configure PC speaker
mov al, 0b6h ; 8253 PIT B6 is load timer 2 mode 3 (squarewave)
out 43h, al
mov ax, 2280 ; Frequency divider (in decimal) for C. 
out 42h, al
mov al, ah
out 42h, al 

call clearscreen

;=====Main loop=====
mainloop:

beep:
test byte [flags], 01h
jz delay
and byte [flags], 0feh;  Clear beep flag
in al, 61h ; Read PORT B
or al, 03h ; Set bits 1 and 0, TIM2GATESPK + SPKRDATA - SH8 and SH9 in schematic
out 61h, al

delay:
mov cx, 1000 ; 15 ms
call delay_15_us ; 

;=====Handle keyboard presses=====

key:
in al, 60h ; Get scan code - might be corrupt but we just need a good guess and can ignore junk
mov bl, al ; Save scan code
mov al, 0c8h ; POST source 5-103 lines 2199-2200 says this write to port B will clear keyboard
out 61h, al 
mov al, 48h ; It will - but we still need it to output again right afterwards.
out 61h, al ; Also disables beep

;=====Parse scan code=====
test bl, 80h
jnz calcy ; Throw away "release" and half the junk
cmp bl, 10h ; Q - Exit and finish POST
je quit
cmp bl, 11h ; W  - Move up
je wpressed
cmp bl, 1Fh ; S  - Move down
je spressed
jmp calcy ; Junk or other key pressed

wpressed:
cmp byte [paddle], 0 ; Can paddle move up?
je calcy ; No
dec byte [paddle] ; Yes, decrease paddle 
jmp calcy

spressed: ; Do nothing now
cmp byte [paddle], 20 ; Can paddle move down?
je calcy ; No
inc byte [paddle] ; Yes, move it
; Fall through


;=====Draw ball=====
calcy:
mov ax, word [bally] ; Ball y position = y position + move per tick (1)
add ax, word [balldy] ; Add delta Y
mov [bally], ax ; Save
cmp ax, 24 ; Hit bottom of screen?
jl checktop ; No
neg word [balldy] ; Yes - change direction
inc byte [flags] ; Beep
jmp calcx
checktop:
cmp ax, 0 ; Hit top of screen?
jg calcx ; No
neg word [balldy] ; Yes, change y direction
inc byte [flags] ; Beep
; Fall through

calcx:
mov ax, word [ballx] ; Ball x position += move pr tick
add ax, word [balldx]
mov [ballx], ax
cmp ax, 142 ; Wall. Each char takes up a word, so x coords are doubled - check right
jl checkleft ; No
neg word [balldx] ; Yes, change direction
inc byte [flags] ; Beep
jmp renderball
checkleft:
cmp ax, 0 ; Hit left side?
jg renderball ; No
neg word [balldx] ; Yes, change direction
inc byte [flags] ; Beep
; Fall through

checkpaddle:
mov ax, word [bally] ; Check if ball missed paddle top
cmp al, byte [paddle]
jl overpaddle ; Lose
sub al, 5
cmp al, byte [paddle] ; Check if ball missed paddle bottom
jg underpaddle ; Lose
inc word [score] ; Yay! Point for us!

mov ax, word [score]
mov cl, 4 ; Let's use the score to change background color!
shl al, cl ; Shift background color to high nibble
mov cx, word [score] ; Use score for foreground too
sub cl, 3 ; We want relatively complementary colors for contrast
and cl, 0fh ; Make sure we only use lower nibble
or al, cl ; Use score -3 as foreground color
mov [color], al ; Save color
jmp newcolor

overpaddle:
underpaddle:
lose:
mov word [score], 0
mov byte [color], 20h ; Default

newcolor:
call clearscreen
mov byte [lastpaddle], -1

renderball:
mov di, [lastball] ; Clear last ball location so we don't need to redraw the whole screen
mov ah, [color]
mov al, 00h
stosw ; Clear last ball location

mov bx, 160 ; Each line is 160 bytes - translate y coordinate to characters
mov ax, [bally] ; Y = number of lines down
mul bx ; Bytes pr line * lines 
add ax, [ballx] ; + how far along the line. 
mov di, ax ; Location in bytes aka memory location
mov [lastball], ax
mov ah, [color] ; Color
mov al, 04h ; Diamond shaped ball
stosw ; Save ball

renderpaddle:
;Draw paddle
xor di,di
xor ch,ch
mov cl, byte [paddle]
cmp word [ballx], 2 ; X inc/decs by 2
je redrawpaddle ; If not we don't need to check last
cmp cl, byte [lastpaddle]
je done ; Even so no need to redraw
redrawpaddle:
mov byte [lastpaddle], cl
call clearscreen
newline:
add di, 160 ; All preceding lines
loop newline
mov cl, 5
mov ah, [color]
mov al, 0b0h ; Good paddle texture, trust me!
drawpaddle:
stosw
add di, 158
loop drawpaddle

done:
jmp mainloop

quit:
retf        ; Return control to BIOS

;=====Subroutines=====
;Clear screen
clearscreen:
push cx
push di
push ax
xor di, di
mov al, 0 ; Write 0 
mov ah, [color] ; Black(0) on green(2)
mov cx, 80*25
REP stosw ; Store the byte in AX at ES:DI and increment DI
xor di,di
mov al, 0deh ; Right half block
mov di, 144
mov cx, 25 ; Every line
drawwall:
stosw
add di, 158
loop drawwall

pop ax
pop di
pop cx
ret

; delay subroutine for XT - Inspired by Sergey Kiselev

delay_15_us:
push ax
push cx

.1: 
    mov al, 10
.2:
    dec al
    jnz .2
loop .1
pop cx
pop ax
ret

codelength equ ($ - start)

section .data align=1
;=====Variables=====
ramstart:
ballx:  dw 0
bally:  dw 0
balldx: dw 0
balldy: dw 0
lastball: dw 0
flags:  db 0
score: dw 0
color: db 0
paddle: db 0
lastpaddle: db 0

ramlength equ ($ - ramstart)

times 16384 - (codelength + ramlength) db 0 ; Fill remaining block space with 0x00
