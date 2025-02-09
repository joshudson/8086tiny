BITS 16

CPU	8086

ORG	100h

; Stupid DIR with no arguments, list root dir of A:
; Knows it's operating on a floppy disk.
_start:
	mov	ax, 0201h
	mov	bx, buffer
	mov	cx, 1
	xor	dx, dx
	int	13h
	jnc	.go1
	mov	ax, 0201h
	int	13h
	jc	short .eve
.go1	mov	ax, [buffer + 0Bh]
	mov	cx, [buffer + 18h]
	mov	dx, [buffer + 1Ah]
	mov	bp, [buffer + 11h]
	add	ax, buffer
	mov	[bytes], ax
	mov	[sectors], cx
	mov	[heads], dx
	mov	ax, [buffer + 16h]
	mov	cl, [buffer + 10h]
	mov	ch, 0
	mul	cx
	add	ax, [buffer + 0Eh]
	mov	di, ax
.rsect	mov	ax, di
	xor	dx, dx
	div	word [sectors]
	mov	cx, dx
	inc	cx
	xor	dx, dx
	div	word [heads]
	mov	ch, al
	xchg	dh, dl
	mov	ax, 0201h
	int	13h
.eve	jc	.error
	mov	si, bx
.entry	mov	al, [si]
	cmp	al, 0
	je	.exit
	cmp	al, 05h
	jne	.ne5
	mov	[si], byte 0E5h
	jmp	.nx5
.exit	ret
.ne5	cmp	al, 0E5h
	je	.next
.nx5	mov	ax, [si + 8]
	mov	cl, [si + 10]
	mov	ch, 13
	mov	[si + 8], byte '.'
	mov	[si + 9], ax
	mov	[si + 11], cx
	mov	[si + 13], word 240Ah
	mov	ah, 9
	mov	dx, si
	int	21h
.next	dec	bp
	jz	.exit
	add	si, 32
	cmp	si, [bytes]
	jne	.entry
	inc	di
	jmp	.rsect
.error	mov	dx, error
	mov	ah, 9
	int	21h
	mov	ax, 4C01h
	int	21h
	db	0CCh
error	db	'Read error on A:', 13, 10, '$'
	align 2, db '$'
_end:
bytes	equ _end
sectors equ bytes + 2
heads	equ bytes + 4
buffer	equ bytes + 6
