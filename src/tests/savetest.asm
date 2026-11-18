; savetest.ws: 64 KB, SRAM 512 KB (save type 05). Each start: the word at SRAM 0 + 1,
; "KARABAS!" at SRAM 2, the word at bank 7 offset FFFE (byte 0x7FFFE, the last sector) + 1.
bits 16
org 0
start:
	cli
	xor ax, ax
	mov ss, ax
	mov sp, 0x2000
	mov ax, 0x1000          ; SRAM segment
	mov ds, ax
	mov es, ax
	xor al, al
	out 0xC1, al            ; SRAM bank 0
	inc word [0]
	mov di, 2
	mov si, msg
	mov cx, 8
.cp:	cs lodsb
	stosb
	loop .cp
	mov al, 7
	out 0xC1, al            ; SRAM bank 7
	inc word [0xFFFE]
	xor al, al
	out 0xC1, al
.end:	jmp .end
msg:	db "KARABAS!"
	times 0xFFF0 - ($ - $$) db 0xFF
	db 0xEA                 ; jmp far F000:0000 (the reset vector at FFFF:0000)
	dw 0x0000, 0xF000
	db 0x00                 ; maintenance
	db 0x00                 ; developer
	db 0x00                 ; mono
	db 0x00                 ; game id
	db 0x00                 ; version
	db 0x00                 ; rom size (1 Mbit... ignored by the core: the file size)
	db 0x05                 ; save type: SRAM 4 Mbit (512 KB)
	db 0x04                 ; flags
	db 0x00                 ; no RTC
	dw 0x0000               ; checksum
