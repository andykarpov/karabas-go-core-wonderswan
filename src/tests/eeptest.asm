; eeptest.ws: 64 KB, EEPROM 16 Kbit (save type 20, 1024 words). Each start: word 0 + 1,
; words 1..2 = "KARA", word 1023 + 1 (the 4th sector).
bits 16
org 0
start:
	cli
	xor ax, ax
	mov ss, ax
	mov sp, 0x2000
	mov ax, 0x1300          ; EWEN: start bit, opcode 00, ext 11
	call cmd40
	xor bx, bx
	call incw
	mov bx, 1
	mov dx, 0x414B          ; "KA"
	call wrw
	mov bx, 2
	mov dx, 0x4152          ; "RA"
	call wrw
	mov bx, 1023
	call incw
.end:	jmp .end

; addr ax, command 40
cmd40:	out 0xC6, al
	mov al, ah
	out 0xC7, al
	mov al, 0x40
	out 0xC8, al
	call dly
	ret

; word bx + 1
incw:	mov ax, bx
	or ax, 0x1800           ; start bit, opcode 10 (read)
	out 0xC6, al
	mov al, ah
	out 0xC7, al
	mov al, 0x10            ; READ
	out 0xC8, al
	call dly
	in al, 0xC4
	mov dl, al
	in al, 0xC5
	mov dh, al
	inc dx
	; fall through: write dx to bx
wrw:	mov al, dl
	out 0xC4, al
	mov al, dh
	out 0xC5, al
	mov ax, bx
	or ax, 0x1400           ; start bit, opcode 01 (write)
	out 0xC6, al
	mov al, ah
	out 0xC7, al
	mov al, 0x20            ; WRITE
	out 0xC8, al
	call dly
	ret

dly:	mov cx, 64
.w:	loop .w
	ret

	times 0xFFF0 - ($ - $$) db 0xFF
	db 0xEA
	dw 0x0000, 0xF000
	db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	db 0x20                 ; save type: EEPROM 16 Kbit
	db 0x04, 0x00
	dw 0x0000
