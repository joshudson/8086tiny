CPU 8086

BITS 16

ORG 0x100

	mov	si, 0x80
	lodsb
	mov	bl, al
	mov	bh, 0
	add	bx, si
	mov	cl, 10
	xor	dx, dx
lop:
	cmp	si, bx
	je	go
	lodsb
	cmp	al, ' '
	je	lop
	cmp	al, 9
	je	lop
	sub	al, '0'
	jb	help
	cmp	al, 9
	ja	help
	xchg	ax, dx
	mul	cl
	add	al, dl
	xchg	ax, dx
	jmp	lop
help:
	mov	dx, msg
	mov	ah, 9
	int	21h
	ret
go:
	xchg	ax, dx
	mov	bx, 0x1234	; Tell emulator to use AL as exit code
	jmp	0:0		; Actual enstruction that exits emulator
msg	db	'Quits 8086tiny emulator', 13, 10, 'Usage: QUITEMU [exit code]', 13, 10, '$'
