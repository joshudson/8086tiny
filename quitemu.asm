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
	mov	bp, 0x1234	; Tell emulator to use AL as exit code
	xor	bx, bx
	mov	ax, 5304h
	int	15h
	mov	ax, 5301h
	int	15h
	mov	ax, 5307h
	mov	cx, 3
	inc	bx
	int	15h
	mov	ax, 4C01h	; Power off failed
	int	21h
	ret			; DOS 1.0
msg	db	'Quits 8086tiny emulator', 13, 10, 'Usage: QUITEMU [exit code]', 13, 10, '$'
