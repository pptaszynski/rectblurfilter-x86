%define	FWIDTH		[ebp-4]
%define FHEIGHT		[ebp-8]
%define IMGSIZE		[ebp-12]
%define CYCLEBUFF	[ebp-16]
%define CYCLEBUFFLAST	[ebp-20]
%define X			[ebp-24]
%define Y			[ebp-28]
%define TOPDST		[ebp-32]
%define	BOTTOMDST	[ebp-36]
%define EXTENDBOTEDGE	[ebp-40]
%define BSUM		[ebp-44]
%define RSUM		[ebp-48]
%define GSUM		[ebp-52]
%define ROWL		[ebp-56]
%define BUFFOFFSET	[ebp-60]
%define	DENOM		[ebp-64]
%define	MASKBEGADR	[ebp-68]		
%define	AVGB		[ebp-72]
%define AVGR		[ebp-76]
%define	AVGG		[ebp-80]
%define	PREV		[ebp-84]
%define	BTRPT		[ebp-88]
%define BUFFPOS		[ebp-92]
%define	DEST		[ebp-96]
%define	SRCPOS		[ebp-100]
global rectBlur
global getPixel
extern malloc
extern free

	section .text

;
;	Argumenty wywolania:
;
;	[ebp+8]		*src
;	[ebp+12]	widht		
;	[ebp+16]	height
;	[ebp+20]	*dest
;	[ebp+24]	fwidth
;	[ebp+28]	fheight
;

rectBlur:
		; Prolog
		push	ebp
        mov		ebp, esp
		sub		esp, 120
		push	edi
		push	esi
		push	ebx

		; oblicz FWIDTH
		mov		eax, [ebp+24]
		shl		eax,1
		inc		eax
		mov		FWIDTH, eax

		; oblicz FHEIGHT
		mov		eax, [ebp+28]
		shl		eax, 1
		inc		eax
		mov		FHEIGHT, eax

		; oblicz IMGSIZE
		mov		eax, [ebp+12]
		mov		edx, [ebp+16]
		mul		edx
		shl		eax, 2
		mov		IMGSIZE, eax
		
		; oblicz ROWL
		mov		eax, [ebp+12]
		lea		ebx, [eax+03*eax]
		mov		ROWL, ebx

	
		;	przygotuj bufor cykliczny w pamieci
		mov		ecx, FWIDTH
		shl		ecx, 2
		mov		eax, ecx
		push	ecx
		push	eax
		call	malloc					; Zwraca adres zaalokowanego obszaru w eax
		sub		esp, -4
		pop		ecx
		mov		CYCLEBUFF, eax
		sub		ecx, 4
		add		eax, ecx
		mov		CYCLEBUFFLAST, eax
		
		mov		Y, dword 0x0
		mov		X, dword 0x0
		
		; ESI - *src
		; EDI - *dst

		mov		ecx, [ebp+16]			; zapisz w ecx imgheight

		; ECX - height

		_vert:
				mov		eax, [ebp+16]	; zapisz w eax imgheight
				sub		eax, ecx		; Oblicz odleglosc od dolnej krawedzi (przy zalozeniu ze obraz przegladamy od dolu)
		; EAX - Odległość od dolnej krawędzi
				mov		BOTTOMDST, eax	; Zapisz jako zm lokalna
				push	ecx				; PUSH ecx na stos -> ECX zawiera HEIGHT
		
		; PUSH ECX -> ECX na stos

			_fillbuff:				
				;; PREPARE A CYCLE BUFFOR WITH COMPTUED AVERAGE
				;; VALUES OF PIXEL COLOURS IN A FILTER WINDOW

				; sub		eax, [ebp+28]
				makebuff:
				mov		edx, [ebp+28]
				sub		edx, eax
				xor		ebx, ebx
				cmp		edx, ebx
				cmovg   ebx, edx
				mov		BTRPT, ebx
				mov		esi, [ebp+8]
				mov		ebx, esi
				mov		edx, ROWL
				push	eax
				mov		eax, [ebp+28]
				mul		edx
				sub		ebx, eax
				mov		esi, ebx
				pop		eax

				mov		MASKBEGADR, esi
				makebuffExtEdge:
					xor		ecx, ecx
					mov		BSUM, ecx
					mov		RSUM, ecx
					mov		GSUM, ecx
					mov		ecx, FHEIGHT
					xor		eax, eax	
					countEdgeValues:
						mov		esi, MASKBEGADR
						mov		edi, [ebp+8]
						xor		ebx, ebx
						cmp		esi, edi
						cmovl   eax, ebx
						add		eax, BTRPT
						mov		ebx, esi
						push	eax
						mul		edx
						lea		esi, [ebx+eax]
						pop		eax
						mov		ebx, IMGSIZE
						add		edi, ebx
						cmp		esi, edi
						cmovge	esi, PREV
						mov		PREV, esi
						mov		ebx, [esi]	; EBX - CAŁY PIKSEL B-R-G-A
						; push	eax			; EAX - LICZNIK WYSOKOSCI W KOLUMNIE -> STOS

						mov		edi, ebx
						; ADD B VALUE
						and		edi, 0xFF000000
						shr		edi, 24
						add		BSUM, edi
						; ADD R VALUE
						mov		edi, ebx
						and		edi, 0x00FF0000
						shr		edi, 16
						add		RSUM, edi
						; ADD G VALUE
						mov		edi, ebx
						and		edi, 0x0000FF00
						shr		edi, 8
						add		GSUM, edi
						; pop		eax			; EAX - LICZNIK WYSOKOSCI W KOLUMNE <- STOS
						sub		eax, BTRPT
						inc		eax	
					loop	countEdgeValues
					
					mov		edi, CYCLEBUFF
					; DZIELIMY WARTOSCI 
					mov		eax, dword BSUM		; BLUE 
					mov		ecx, dword FHEIGHT
					div		ecx 
					mov		ah, al
					mov		[edi], al		; Zapisujemy w buforze
						
					mov		eax, dword RSUM		; RED
					mov		ecx, FHEIGHT
					div		ecx
					mov		bl, al
					mov		[edi+1], al		; Zapisujemy w buforze
						
					mov		eax, dword GSUM		; GREEN
					mov		ecx, FHEIGHT	
					div		ecx
					mov		bh, al
					mov		[edi+2], al		; Zapisujemy w buforze
						
					add		edi, 0x4
					;; WYPELNIANIE POCZATKU BUFORA - ROZSZERZANIE KRAWEDZI
					mov		ecx, [ebp+24]
					extLEdgeLoop:
						mov		[edi], ah
						mov		[edi+1], bl
						mov		[edi+2], bh
						add		edi, 0x4
						mov		BUFFPOS, edi
					loop	extLEdgeLoop
					
				;; NOW WE HAVE FILLED FIRST W+1 POS. OF CYCLEBUFFER FILLED WITH
				;; THE AVERAGE VALUES OF LEF EDGE PIXELS

				;; FILL REST OF BUFFER
				;; EDI - CURRENT BUFFER POS ADRES
				;; ESI - BEG OF MASK ADR
				mov		esi, MASKBEGADR
				mov		ecx, [ebp+24]
				xor		eax, eax
				makeBuffXLoop:
					inc		eax
					add		esi, 0x4
					mov		MASKBEGADR, esi
					push	eax				; EAX - LICZNIK pozycji X -> STOS
					push	ecx				; ECX - licznik petli	X -> STOS
						
					xor		ecx, ecx
					mov		BSUM, ecx
					mov		RSUM, ecx
					mov		GSUM, ecx
					mov		ecx, FHEIGHT
					xor		eax, eax
					mov		edx, ROWL
					push	esi				; ESI -> STOS
					makeBuffYLoop:
						;mov		esi, MASKBEGADR
						;mov		edi, [ebp+8]
						;xor		ebx, ebx
						;cmp		esi, edi
						;cmovl   eax, ebx
						;add		eax, BTRPT
						;mov		ebx, esi
						;push	eax
						;mul		edx
						;lea		esi, [ebx+eax]
						;pop		eax
						;mov		ebx, IMGSIZE
						;add		edi, ebx
						;cmp		esi, edi
						;cmovge	esi, PREV
						;mov		PREV, esi
						;mov		ebx, [esi]	; EBX - CAŁY PIKSEL B-R-G-A
						mov		esi, MASKBEGADR
						mov		edi, [ebp+8]
						xor		ebx, ebx
						cmp		esi, edi
						cmovl   eax, ebx
						add		eax, BTRPT
						mov		ebx, esi						
						push	eax
						mul		edx
						lea		esi, [esi+eax]
						pop		eax
						mov		ebx, IMGSIZE
						add		edi, ebx
						cmp		esi, edi
						cmovge	esi, PREV
						mov		PREV, esi
						;push	eax
						;mul		edx
						;lea		esi, [ebx+eax]
						;pop		eax
						mov		ebx, [esi]	; EBX - CAŁY PIKSEL B-R-G-A
						;pop		esi
						;push	eax			; EAX - LICZNIK WYSOKOSCI W KOLUMNIE -> STOS

						mov		edi, ebx	
						; ADD B VALUE
						and		edi, 0xFF000000
						shr		edi, 24
						add		BSUM, edi
						; ADD R VALUE
						mov		edi, ebx
						and		edi, 0x00FF0000
						shr		edi, 16
						add		RSUM, edi
						; ADD G VALUE
						mov		edi, ebx
						and		edi, 0x0000FF00
						shr		edi, 8
						add		GSUM, edi

						sub		eax, BTRPT
						inc		eax
					loop	makeBuffYLoop
					pop		esi
					; DZIELIMY WARTOSCI 
					mov		edi, BUFFPOS
					mov		eax, BSUM
					mov		ecx, FHEIGHT
					div		ecx
					mov		[edi], al		; Zapisujemy w buforze

					mov		eax, RSUM
					mov		ecx, FHEIGHT
					div		ecx
					mov		[edi+1], al	; Zapisujemy w buforze
					
					mov		eax, GSUM
					mov		ecx, FHEIGHT
					div		ecx
					mov		[edi+2], al	; Zapisujemy w buforze

					add		edi, 0x4
					mov		BUFFPOS, edi

					pop		ecx
					pop		eax
					sub		ecx, 1
				jnz	makeBuffXLoop
				mov		esi, CYCLEBUFF
				mov		BUFFPOS, esi
				mov	    esi, [ebp+8]
				mov		ecx, X
				mov		eax, Y
				mov		edx, ROWL
				imul		ecx
				add		esi, eax
				add		esi, ecx
				; lea		esi,[ebx+eax+ecx]
				mov		SRCPOS, esi
				mov		ecx, [ebp+12]
				xor		eax, eax
				mov		X, eax
				_hor:
					;; COMPUTE AV VALUES FOR PIXEL
					xor		ebx, ebx
					mov		BSUM, ebx
					mov		RSUM, ebx
					mov		GSUM, ebx
					push	ecx				; ECX -> STOS
					
					mov		ecx, FWIDTH
					_sumBuff:
						mov	esi, CYCLEBUFF
						mov ebx, [esi]
						
						mov		eax, ebx	
						; ADD B VALUE
						and		eax, 0xFF000000
						shr		eax, 24
						add		BSUM, eax
						; ADD R VALUE
						mov		eax, ebx
						and		eax, 0x00FF0000
						shr		eax, 16
						add		RSUM, eax
						; ADD G VALUE
						mov		eax, ebx
						and		eax, 0x0000FF00
						shr		eax, 8
						add		GSUM, eax
						
						add		esi, 0x04
					loop	_sumBuff
						xor		ebx, ebx
						; DZIELIMY WARTOSCI 
						mov		eax, BSUM
						mov		ecx, FWIDTH
						div		ecx
						shl		eax, 24
						and		eax,0xFF000000
						or		ebx, eax		; Zapisujemy w buforze
						
						mov		eax, RSUM
						mov		ecx, FWIDTH
						div		ecx
						shl		eax, 16
						and		eax, 0x00FF0000
						or		ebx, eax
						
						mov		eax, GSUM
						mov		ecx, FWIDTH
						div		ecx
						shl		eax, 8
						and		eax, 0x0000FF00
						or		ebx, eax
						
						mov		esi, SRCPOS
						mov		eax, [esi]
						and		eax, 0x000000FF
						and		ebx, eax
						
						push	ebx
						push	edx
						push	ecx

						mov	    edi, [ebp+20]
						mov		ecx, X
						mov		eax, Y
						mov		edx, ROWL
						mul		edx
						add		edi, eax
						add		edi, ecx
						; lea		edi,[ebx+eax+ecx]

						mov		eax, ebx
						stosb

						pop		ecx
						pop		edx
						pop		ebx
						
						mov		ecx, [ebp+12]
						mov		eax, X
						add		eax, [ebp+24]
						cmp		eax, ecx
						jl		addToBuffLoopPROL
							mov		esi, CYCLEBUFFLAST
							mov		eax, [esi]
							mov		edi, BUFFPOS
							stosb
							cmp		edi, CYCLEBUFFLAST
							cmovg	edi, CYCLEBUFF
							mov		edi, BUFFPOS
							jmp		addedToBuff
						;; REPLACE NEXT COLUMN IN BUFFER
						addToBuffLoopPROL:
						mov		esi, SRCPOS
						mov		eax, [ebp+24]
						shl		eax, 2
						add		esi, eax
						mov		eax, [ebp+28]
						mov		edx, ROWL
						mul		edx
						sub		esi, eax
						mov		ecx, FHEIGHT
						xor		eax, eax
						addToBuffYLoop:
							mov		edi, [ebp+8]
							xor		ebx, ebx
							cmp		esi, edi
							cmovl   eax, ebx
							add		eax, BTRPT
							mov		ebx, esi
							push	eax
							mul		edx
							lea		esi, [ebx+eax]
							mov		ebx, IMGSIZE
							add		edi, ebx
							cmp		esi, edi
							cmovge	esi, PREV
							mov		PREV, esi
							;push	esi
							;lea		esi, [ebx+eax]
							mov		ebx, [esi]	; EBX - CAŁY PIKSEL B-R-G-A
							;pop		esi
							; push	eax			; EAX - LICZNIK WYSOKOSCI W KOLUMNIE -> STOS

							mov		edi, ebx	
							; ADD B VALUE
							and		edi, 0xFF000000
							shr		edi, 24
							add		BSUM, edi
							; ADD R VALUE
							mov		edi, ebx
							and		edi, 0x00FF0000
							shr		edi, 16
							add		RSUM, edi
							; ADD G VALUE
							mov		edi, ebx
							and		edi, 0x0000FF00
							shr		edi, 8
							add		GSUM, edi
							
							pop		eax
							sub		eax, BTRPT
							inc		eax
						loop	addToBuffYLoop
						; DZIELIMY WARTOSCI
						mov		edi, BUFFPOS
						mov		eax, BSUM
						mov		ecx, FHEIGHT
						div		ecx
						mov		[edi], al		; Zapisujemy w buforze
						
						mov		eax, RSUM	
						mov		ecx, FHEIGHT
						div		ecx
						mov		[edi+1], al	; Zapisujemy w buforze
						
						mov		eax, GSUM
						mov		ecx, FHEIGHT
						div		ecx
							
						mov		[edi+2], al	; Zapisujemy w buforze

						add		edi, 0x4
						cmp		edi, CYCLEBUFFLAST
						cmovg	edi, CYCLEBUFF
						mov		edi, BUFFPOS
						addedToBuff:
						mov		eax, X
						inc		eax
						mov		X, eax
						pop		ecx
						sub		ecx, 1
						jnz		_hor
				pop		ecx
				mov		eax, Y
				inc		eax
				mov		Y, eax
				sub		ecx, 1
				jnz		_vert


end:
		; Epilog
		mov		eax, CYCLEBUFF
		push	eax
		call	free
		add		esp, 4

		pop		ebx
		pop		edi
		pop		esi

		add		esp, 120

		leave
        ret

_getPixel:
		; Prolog
		push	ebp
        mov		ebp, esp
		push	edi
		push	esi
		push	ebx

		

		; Epilog
		pop		ebx
		pop		edi
		pop		esi

		leave
        ret
