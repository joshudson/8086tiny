CPU 8086

BITS 16

ORG 0x100

_start:
	mov	si, 0x80
	lodsb
	mov	ah, 0
	xchg	ax, bp
	add	bp, si
.sx	cmp	si, bp
	je	.usage
	lodsb
	call	ucase
	cmp	al, ' '
	jbe	.sx
	cmp	al, '/'
	je	.sw
	xor	bp, bp
	cmp	al, 'H'
	je	harddisk
	cmp	al, 'S'
	je	harddisk
	cmp	al, 'F'
	je	floppydisk
	cmp	al, 'M'
	je	mbr
.usage	mov	dx, s_usage
	mov	ah, 9
	int	21h
	mov	ax, 4C01h
	int	21h
.sw	cmp	si, bp
	je	.usage
	lodsb
	call	ucase
	cmp	al, 'K'
	jne	.usage
.ks	mov	di, s_bootfilenamereal
	cmp	si, bp
	je	.usage
	lodsb
	cmp	al, ' '
	ja	.usage
.ks1	cmp	si, bp
	je	.usage
	lodsb
	cmp	al, ' '
	jbe	.ks4
	cmp	al, '.'
	je	.ks2
	cmp	di, s_bootfilenamereal + 8
	jae	.ks1
	call	ucase
	stosb
	jmp	.ks1
.ks2	mov	cx, s_bootfilenamereal + 8
	sub	cx, di
	jbe	.ks3
	mov	al, ' '
	rep	stosb
.ks3	cmp	si, bp
	je	.usage
	lodsb
	cmp	al, ' '
	jbe	.ks4
	call	ucase
	cmp	di, s_bootfilenamereal + 11
	jae	.ks3
	stosb
	jmp	.ks3
.ks4	mov	al, ' '
	mov	cx, s_bootfilenamereal + 11
	sub	cx, di
	jbe	.sx
	rep	stosb
	jmp	.sx

ucase	cmp	al, 'a'
	jb	.ret
	cmp	al, 'z'
	ja	.ret
	sub	al, 'a' - 'A'
.ret	ret

harddisk:
	mov	si, hostdap
	mov	[si + 6], ds
	mov	[si + 8], bp
	mov	[si + 10], bp
	mov	[si + 12], bp
	mov	[si + 14], bp
	mov	dl, 80h
	mov	ah, 42h
	int	13h
	jc	ioerror
	mov	si, 1000h + 512 - 66 - 16
	mov	cx, 4
.scan	add	si, 16
	test	[si], byte 80h
	jnz	.found
	loop	.scan
	mov	dx, s_nobootpart
	mov	ah, 9
	int	21h
	mov	ax, 4C01h
	int	21h
.found	cmp	[si + 4], byte 0Ch
	je	.fatlba
	cmp	[si + 4], byte 0Eh
	je	.fatlba
	mov	dx, s_notfatlba
	mov	ah, 9
	int	21h
	mov	ax, 4C01h
	int	21h
.fatlba	mov	ax, [si + 8]
	mov	dx, [si + 10]
	mov	si, hostdap
	mov	[si + 8], ax
	mov	[si + 10], dx
	mov	dl, 80h
	mov	ah, 42h
	int	13h
	jc	ioerror
	mov	si, [si + 4]
	cmp	[si + sectorsperfat - 7C00h], word 0
	je	.fat32c
	xor	dx, dx
	mov	ax, [si + totalsectors - 7C00h]
	or	ax, ax
	jnz	.szld32
	mov	ax, [si + totalsectors32 - 7C00h]
	mov	dx, [si + totalsectors32 - 7C00h + 2]
.szld32	sub	ax, [si + reservedsectors - 7C00h]
	sbb	dx, 0
	mov	ch, 0
	mov	cl, [si + numfats - 7C00h]
.slp	sub	ax, [si + sectorsperfat - 7C00h]
	sbb	dx, 0
	loop	.slp
	mov	ch, 0
	mov	cl, [si + sectorspercluster - 7C00h]
	div	cx		; Cannot overflow unless FS is malformed
	mov	di, .fat12
	cmp	ax, 0FF4h
	ja	.fat16c
	jmp	.go
.fat16c	mov	di, .fat16
	jmp	.go
.fat32c	mov	di, .fat32
.go	mov	[si], word 0EBh + (codeoffset - 7C00h - 2) * 100h
	mov	[si + 2], byte 90h
	mov	ax, [hostdap + 8]
	mov	dx, [hostdap + 10]
	mov	[si + hiddensectors - 7C00h], ax
	mov	[si + hiddensectors - 7C00h + 2], dx
	mov	bx, di
	mov	si, s_ioerror
	mov	di, diskerrorstart - 7C00h + 1000h
	mov	cx, (7DFEh - diskerrorstart) / 2
	rep	movsw
	mov	di, codeoffset - 7C00h + 1000h
	jmp	bx

.fat12	mov	si, boot16
	mov	[si + boot16.ldcluster - boot16], word codeoffset + boot16_end - boot16
	mov	[si + boot16.ldsectors - boot16], word codeoffset + boot16_end - boot16 + walkfat12_end - walkfat12
	mov	cx, boot16_end - boot16
	rep	movsb
	mov	si, walkfat12
	mov	cx, walkfat12_end - walkfat12
	rep	movsb
	mov	si, readsectors_lba
	mov	cl, readsectors_lba_end - readsectors_lba
	rep	movsb
	jmp	.go2

.fat16	mov	si, boot16
	mov	[si + boot16.ldcluster - boot16], word codeoffset + boot16_end - boot16
	mov	[si + boot16.ldsectors - boot16], word codeoffset + boot16_end - boot16 + walkfat16_end - walkfat16
	mov	cx, boot16_end - boot16
	rep	movsb
	mov	si, walkfat16
	mov	cl, walkfat16_end - walkfat16
	rep	movsb
	mov	si, readsectors_lba
	mov	cl, readsectors_lba_end - readsectors_lba
	rep	movsb
	jmp	.go2

.fat32	mov	[1001h], byte codeoffset32 - 7C00h - 2
	mov	si, bootlba32
	mov	di, codeoffset32 - 7C00h + 1000h
	mov	cx, (bootlba32_end - bootlba32 + 1) / 2
	rep	movsw

.go2	mov	cx, diskerrorstart - 7C00h + 1000h
	sub	cx, di
	jbe	.go3
	mov	al, 0CCh
	rep	stosb
.go3	mov	si, hostdap
	mov	ax, 4300h
	mov	dl, 80h
	int	13h
	jc	ioerror
	mov	ax, 4C00h
	int	21h

ioerror:
	mov	dx, s_hostioerror
	mov	ah, 9
	int	21h
	mov	ax, 4C02h
	int	21h

mbr:
	mov	si, hostdap
	mov	[si + 6], ds
	mov	[si + 8], bp
	mov	[si + 10], bp
	mov	[si + 12], bp
	mov	[si + 14], bp
	mov	dl, 80h
	mov	ah, 42h
	int	13h
	jc	ioerror
	mov	si, bootmbr
	mov	di, 1000h
	mov	cx, (bootmbr_end - bootmbr) / 2
	rep	movsw
	mov	si, s_ioerror
	mov	di, 10E0h
	mov	cl, 5
	rep	movsw
	mov	di, 10F0h
	mov	si, s_cantfindbootfile
	mov	cl, 4
	rep	movsw
	mov	si, s_bootpart
	mov	cl, 15
	rep	movsb
	mov	si, hostdap
	mov	ax, 4300h
	int	13h
	jc	ioerror
	mov	ax, 4C00h
	int	21h

floppydisk:
	mov	bx, 1000h
	mov	cx, 1
	xor	dx, dx
	mov	ax, 201h
	int	13h
	jc	ioerror
	mov	[bx], word 0EBh + (codeoffset - 7C00h - 2) * 100h
	mov	[bx + 2], byte 90h
	mov	[bx + hiddensectors - 7C00h], bp
	mov	[bx + hiddensectors - 7C00h + 2], bp
	mov	si, s_ioerror
	lea	di, [bx + diskerrorstart - 7C00h]
	mov	cx, (7DFEh - diskerrorstart) / 2
	rep	movsw
	mov	[di - 1], byte 0
	lea	di, [bx + codeoffset - 7C00h]
	mov	si, boot16
	mov	[si + boot16.ldcluster - boot16], word codeoffset + boot16_end - boot16
	mov	[si + boot16.ldsectors - boot16], word codeoffset + boot16_end - boot16 + walkfat12_end - walkfat12
	mov	cx, boot16_end - boot16
	rep	movsb
	mov	si, walkfat12
	mov	cl, walkfat12_end - walkfat12
	rep	movsb
	mov	si, readsectors_chs
	mov	cl, readsectors_chs_end - readsectors_chs
	rep	movsb
	mov	cx, diskerrorstart - 7C00h + 1000h
	sub	cx, di
	jbe	.go
	mov	al, 0CCh
	rep	stosb
.go	mov	cx, 1
	xor	dx, dx
	mov	ax, 301h
	int	13h
	jc	ioerror
	mov	ax, 4C00h
	int	21h

	align	2, db 0CCh
bootmbr:
	xor	ax, ax
	mov	ds, ax
	mov	es, ax
	cli
	mov	ss, ax
	mov	sp, 7C00h
	sti
	mov	si, sp
	mov	di, 0600h
	mov	cx, 100h
	rep	movsw
	jmp	60h:(bootmbr.codebase - bootmbr)
.codebase:
	mov	si, 0800h - 66
	mov	cx, 4
.srch	test	[si], byte 80h
	jnz	.found
	add	si, 16
	loop	.srch
	mov	si, 06F0h
	mov	cx, 23
.error	lodsb
	mov	ah, 0eh
	mov	bx, 7
	int	10h
	loop	.error
	int	18h
.hlt	hlt
	jmp	.hlt
.found	xor	bp, bp
	mov	bx, sp
	mov	ax, [si + 8]
	mov	cx, [si + 10]
	push	si
	mov	si, 0600h
	mov	[si], word 16
	mov	[si + 2], word 1
	mov	[si + 4], bx
	mov	[si + 6], es
	mov	[si + 8], ax
	mov	[si + 10], cx
	mov	[si + 12], bp
	mov	[si + 14], bp
	mov	ah, 42h
	int	13h
	jc	.ioe
	pop	si
	jmp	07C0h:0
.ioe	mov	si, 06E0h
	mov	cx, 10
	jmp	.error
	align	2, db 0CCh
bootmbr_end:

; 0060:0000 kernel load address
; 0000:7C00 bootsector entry point
; 2700:0000 top of kernel
; 1FC0:7800 cluster list (may be overwritten by last read)
; 1FC0:7A00 top of stack
; 1FC0:7C00 bottom of stack
; 1FC0:7C00 bootsector code
boot16:
	cld
	mov	bp, 7C00h
	xor	ax, ax
	mov	ds, ax
	mov	ax, 1FC0h
	mov	es, ax
	mov	si, bp
	mov	di, bp
	mov	[si + 1FDh], dl
	mov	cx, 00FFh
	rep	movsw
	jmp	1FC0h:codeoffset + .codebase - boot16
	align	2, db 0CCh
.lxi	dw	0060h
.ldsectors	dw	0
.ldcluster	dw	0
.codebase:
	sub	bp, 18
	cli
	mov	ss, ax
	mov	sp, bp
	mov	ds, ax
	sti

	; Scan root directory
	mov	es, [codeoffset + .lxi - boot16]
	xor	ax, ax
	mov	ch, 0
	mov	cl, [numfats]
.sfx	add	ax, [sectorsperfat]
	loop	.sfx
	mov	[bp + 16], ax	; BP + 16 = sectors in all fats
	mov	bx, [rootdirentries]
	add	bx, 15
	mov	cl, 4
	shr	bx, cl
	add	[bp + 16], bx	; BP + 16 = sectors in all fats + root sectors
	mov	cx, bx
	push	es
	xor	dx, dx
	call	.loadsectors2
	pop	es
	mov	cx, [rootdirentries]
.sloop	xor	di, di
	mov	si, bootfilenamereal
	push	cx
	mov	cx, 11
	repe	cmpsb
	pop	cx
	je	short .found
	mov	ax, es
	inc	ax
	inc	ax
	mov	es, ax
	loop	.sloop
.ferror	mov	cx, 7DFDh - nokernelstart
	mov	si, nokernelstart
.error	mov	ah, 0Eh
	mov	bx, 7
.eloop	lodsb
	int	10h
	loop	.eloop
	int	18h
.hlt	hlt
	jmp	.hlt
.found	mov	ax, [es:1Ah]
	push	ax

	; Load FAT for jumping around
	mov	es, [codeoffset + .lxi - boot16]
	xor	ax, ax
	xor	dx, dx
	mov	cx, [sectorsperfat]
	call	.loadsectors2

	; Follow the FAT chain
	mov	di, 7800h
	pop	ax
.walk	push	ds
	pop	es
	stosw
	call	[codeoffset + .ldcluster - boot16]
	jb	.walk
	mov	si, 7800h
	mov	es, [codeoffset + .lxi - boot16]
.llp	lodsw
	dec	ax
	dec	ax
	mov	ch, 0
	mov	cl, [sectorspercluster]
	mul	cx
	add	ax, [bp + 16]
	adc	dx, 0
	push	si
	call	.loadsectors2
	pop	si
	cmp	si, di
	jb	.llp
	mov	bl, [7DFDh]	; Kernel expects boot disk in BL
	jmp	0060h:0000h
.diskerror:
	mov	cx, nokernelstart - diskerrorstart
	mov	si, diskerrorstart
	jmp	.error

.loadsectors2:
	add	ax, [reservedsectors]
	adc	dx, 0
	add	ax, [hiddensectors]
	adc	dx, [hiddensectors + 2]
.loadsectors2_next:
	push	cx
	cmp	cx, 32
	jbe	.loadsectors2_last
	mov	cx, 32
.loadsectors2_last:
	push	ax
	push	dx
	push	cx
	call	[codeoffset + .ldsectors - boot16]
	jc	short .diskerror
	pop	bx
	pop	dx
	pop	ax
	add	ax, bx
	adc	dx, 0
	mov	cl, 5
	shl	bx, cl
	mov	cx, es
	add	cx, bx
	mov	es, cx
	pop	cx
	sub	cx, 32
	ja	.loadsectors2_next
	ret
boot16_end:

walkfat16:
	mov	dx, 0060h
	shl	ax, 1
	jnc	.nov
	add	dh, 10h
.nov	mov	es, dx
	xchg	ax, bx
	mov	ax, [es:bx]
	cmp	ax, 0FFF7h
	ret
walkfat16_end:

walkfat12:
	mov	es, [codeoffset + boot16.lxi - boot16]
	mov	bx, ax
	add	bx, ax
	add	bx, ax
	shr	bx, 1
	mov	ax, [es:bx]
	jc	.odd
	and	ax, 0FFFh
	jmp	.even
.odd	mov	cl, 4
	shr	ax, cl
.even	cmp	ax, 0FF7h
	ret
walkfat12_end:

readsectors_lba:
	xor	si, si
	mov	[bp], word 16
	mov	[bp + 2], cx
	mov	[bp + 4], si
	mov	[bp + 6], es
	mov	[bp + 8], ax
	mov	[bp + 10], dx
	mov	[bp + 12], si
	mov	[bp + 14], si
	mov	si, bp
	mov	ah, 42h
	mov	dl, [7DFDh]
	int	13h
	ret
readsectors_lba_end:

readsectors_chs:	; Only used for floppy disks: can't handle more than 255 tracks
	mov	bx, cx
	div	word [sectorspertrack]
	mov	cl, dl
	inc	cl
	xor	dx, dx
	div	word [heads]
	mov	dh, dl
	mov	ch, al
	mov	al, bl
	mov	ah, 02h
	mov	dl, [7DFDh]
	xor	bx, bx
	int	13h
	ret
readsectors_chs_end:

	align 2, db 0CCh
;Boot time memory map
; 0060:0000 kernel load address
; 0000:7C00 bootsector entry point
; 2700:0000 top of kernel
; 1FC0:7800 FAT32 buffer (may be overwritten by last read)
; 1FC0:7A00 top of stack
; 1FC0:7C00 bottom of stack
; 1FC0:7C00 bootsector code

bootlba32:
	cld
	mov	bp, 7C00h
	xor	ax, ax
	mov	ds, ax
	mov	ax, 1FC0h
	mov	es, ax
	mov	si, bp
	mov	di, bp
	mov	[si + 1FDh], dl
	mov	cx, 00FFh
	rep	movsw
	jmp	1FC0h:codeoffset32 + .codebase - bootlba32
.codebase:
	sub	bp, 24
	cli
	mov	ss, ax
	mov	sp, bp
	mov	ds, ax
	sti
	mov	ax, 0060h
	mov	es, ax
	mov	ax, [rootdircluster]	; Open root directory entry
	mov	dx, [rootdircluster + 2]
	mov	[bp + 16], ax
	mov	[bp + 18], dx
	mov	cx, 0FFFFh
	mov	[bp + 20], cx	; Impossible value force reload
	mov	[bp + 22], cx
.ndir	mov	cx, 1
	call	.readcluster
	mov	bl, 0
	mov	bh, [sectorspercluster]
	shl	bh, 1
	xor	di, di
	mov	si, bootfilenamereal
.find	push	di
	mov	cx, 11
	repe	cmpsb
	pop	di
	je	.found
	add	di, 32
	cmp	di, bx
	jb	.find
	call	.isnext
	jb	short .ndir
	mov	cx, 7DFDh - nokernelstart
	mov	si, nokernelstart
	jmp	.error
.found:	mov	dx, [es:di + 0x14]
	mov	ax, [es:di + 0x1A]
	mov	[bp + 16], ax
	mov	[bp + 18], dx
.kload	call	.readcluster
	mov	ax, es
	mov	bl, [sectorspercluster]	; we loaded sectorspercluster * 512 / 16 paragraphs
	mov	bh, 0
	mov	cl, 5
	shl	bx, cl
	add	ax, bx
	mov	es, ax
	call	.isnext
	jb	.kload
	mov	bl, [7DFDh]	; Kernel expects boot disk in BL
	jmp	0060h:0000h
.isnext	cmp	[bp + 16], word 12h ;0FFF7h
	jb	.ret
	cmp	[bp + 18], word 0FFFh
.ret	ret
.readcluster:
	; Get next cluster for chain control
	xor	si, si
	mov	di, 7800h
	mov	ax, [bp + 16]
	mov	dx, [bp + 18]
	; Now divide by 128 to get sector offset into FAT
	shl	ax, 1
	rcl	dx, 1
	mov	al, ah
	mov	ah, dl
	mov	dl, dh
	mov	dh, 0
	cmp	ax, [bp + 20]
	jne	.rcds
	cmp	dx, [bp + 22]
	je	.rchs
.rcds	mov	[bp + 20], ax
	mov	[bp + 22], dx
	mov	[bp + 4], di
	mov	[bp + 6], ds
	mov	cl, 1
	call	.readsector
	xor	si, si
.rchs	mov	ax, [bp + 16]
	mov	dx, [bp + 18]
	mov	bl, [bp + 16]
	and	bx, 127
	shl	bx, 1
	shl	bx, 1
	mov	cx, [bx + di]
	mov	bx, [bx + di + 2]
	and	bh, 0Fh
	mov	[bp + 16], cx
	mov	[bp + 18], bx
	sub	ax, 2
	sbb	dx, si
	mov	cl, [sectorspercluster]
.spcn	shr	cl, 1
	jz	.spcx
	shl	ax, 1
	rcl	dx, 1
	jmp	.spcn
.spcx	mov	ch, 0
	mov	cl, [numfats]
.sf	add	ax, [sectorsperfat32]
	adc	dx, [sectorsperfat32 + 2]
	loop	.sf
	mov	[bp + 4], si
	mov	[bp + 6], es
	mov	cl, [sectorspercluster]
	call	.readsector
.sret	ret
.readsector:		; Inputs: DX:AX = sector; SI = 0, BP6:BP+4 = address, CL = number of sectors (limit 64)
			; Preserves BX, CL, DI, BP
	mov	ch, 0
	add	ax, [hiddensectors]	; Add in stuff before first FAT
	adc	dx, [hiddensectors + 2]
	add	ax, [reservedsectors]
	adc	dx, si
	mov	[bp], word 16
	mov	[bp + 2], cx
	mov	[bp + 8], ax
	mov	[bp + 10], dx
	mov	[bp + 12], si
	mov	[bp + 14], si
	mov	dl, [7DFDh]
	mov	si, bp
	mov	ah, 42h
	int	13h
	jnc	.sret
	mov	si, diskerrorstart
	mov	cx, nokernelstart - diskerrorstart
.error	mov	ah, 0Eh
	mov	bx, 7
.eloop	lodsb
	int	10h
	loop	.eloop
	int	18h
.hlt	hlt
	jmp	.hlt
	align	2, db 0CCh
bootlba32_end:

s_ioerror		db	'Disk Error'
s_cantfindbootfile	db	'Missing '
s_bootfilenamereal	db	'KERNEL  SYS'
			db	80h
s_hostioerror		db	'Disk Error', 13, 10, '$'
s_nobootpart		db	'No boot partiton found', 13, 10, '$'
s_notfatlba		db	'Only LBA supported on hard disks', 13, 10, '$'
s_usage			db	'Installs the correct boot sector for 8086tiny', 13, 10
s_bootpart		db	'boot partition'
			db	'Usage: FIXBOOT [/K KERNEL.SYS] {HD|FD|MBR}', 13, 10, '$'
	align 2, db '$'
hostdap		dw	16
		dw	1
		dw	1000h

bytespersector		equ	7C0Bh
sectorspercluster	equ	7C0Dh
reservedsectors		equ	7C0Eh
numfats			equ	7C10h
rootdirentries		equ	7C11h
totalsectors		equ	7C13h
mediadescriptor		equ	7C15h
sectorsperfat		equ	7C16h
sectorspertrack		equ	7C18h
heads			equ	7C1Ah
hiddensectors		equ	7C1Ch
totalsectors32		equ	7C20h
drivenumber		equ	7C24h
flags			equ	7C25h
ebootsig		equ	7C26h
volumeserial		equ	7C27h
volumelabel		equ	7C2Bh
fstype			equ	7C36h
codeoffset		equ	7C3Eh

sectorsperfat32		equ	7C24h
flags2_32		equ	7C28h
version32		equ	7C2Ah
rootdircluster		equ	7C2Ch
fsinfosector		equ	7C30h
bootbaksector		equ	7C32h
bootfilename		equ	7C34h
drivenumber32		equ	7C40h
flags32			equ	7C41h
ebootsig32		equ	7C42h
volumeserial32		equ	7C43h
volumelabel32		equ	7C47h
fstype32		equ	7C52h
codeoffset32		equ	7C5Ah

bootfilenamereal	equ	7DF2h
nokernelstart		equ	7DEAh
diskerrorstart		equ	7DE0h
