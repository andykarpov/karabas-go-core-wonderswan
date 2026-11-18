; rtctest.ws: 64 KB, SRAM 8 KB (save type 01), RTC. At the start the date and time of the cartridge
; RTC (command 15: year month day weekday hour minute second, BCD) go to SRAM 0..6, then again and
; again to SRAM 8..14 (the .sav holds the time of its last save).
bits 16
org 0
start:
	cli
	xor ax, ax
	mov ss, ax
	mov sp, 0x2000
	mov ax, 0x1000
	mov es, ax
	xor al, al
	out 0xC1, al
	xor di, di
	call rd
.again:	mov di, 8
	call rd
	mov cx, 0
.w:	loop .w
	jmp .again

rd:	mov al, 0x15
	out 0xCA, al
	mov cx, 7
.b:	in al, 0xCB
	stosb
	loop .b
	ret

	times 0xFFF0 - ($ - $$) db 0xFF
	db 0xEA
	dw 0x0000, 0xF000
	db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	db 0x01                 ; save type: SRAM 64 Kbit
	db 0x04
	db 0x01                 ; RTC
	dw 0x0000
