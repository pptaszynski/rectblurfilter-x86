%define	FWIDTH		[ebp-4]
%define FHEIGHT		[ebp-8]
%define IMGSIZE		[ebp-12]
%define CYCLEBUFF	[ebp-16]
%define CYCLEBUFFLAST	[ebp-20]
%define X			[ebp-24]
%define Y			[ebp-28]
;%define TOPDST		[ebp-32]
%define BSUM		[ebp-44]
%define RSUM		[ebp-48]
%define GSUM		[ebp-52]
%define ROWL		[ebp-56]
%define	MASKBEGADR	[ebp-68]		
%define	AVGB		[ebp-72]
%define AVGR		[ebp-76]
%define	AVGG		[ebp-80]
%define	PREV		[ebp-84]
%define	BTRPT		[ebp-88]
%define BUFFPOS		[ebp-92]
%define	DSTPOS		[ebp-96]
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
		add		esp, 4
		pop		ecx
		mov		CYCLEBUFF, eax
		sub		ecx, 4
		add		eax, ecx
		mov		CYCLEBUFFLAST, eax
		
		mov		Y, dword 0x0
		mov		X, dword 0x0
		
		mov		ecx, [ebp+8]
		mov		SRCPOS, ecx
		mov		ecx, [ebp+20]
		mov		DSTPOS, ecx
		; ESI - *src
		; EDI - *dst

		; ECX - height

		_vert:
				mov		eax, Y	; wysokosc w obrazku
				;sub		eax, ecx		; Oblicz odleglosc od dolnej krawedzi (przy zalozeniu ze obraz przegladamy od dolu)
		; EAX - Odległość od dolnej krawędzi
		
		; PUSH ECX -> ECX na stos - LICZNIK PETLI PRZEBIEGU PIONOWEGO

			_fillbuff:				
				;; PREPARE A CYCLE BUFFOR WITH COMPTUED AVERAGE
				;; VALUES OF PIXEL COLOURS IN A FILTER WINDOW

				; sub		eax, [ebp+28]
				makebuff:
				; COMPUTE THEORETICAL ADRES TO A FIRST PIXEL UNDER FILTER MASK
				mov		edx, [ebp+28]
				mov		eax, Y
				sub		edx, eax
				xor		ebx, ebx
				cmp		edx, ebx
				cmovg   ebx, edx
				mov		BTRPT, ebx
				mov		esi, [ebp+8]
				mov		edx, ROWL
				; push	eax
				sub		eax, [ebp+28]
				imul	edx
				add		esi, eax

				mov		MASKBEGADR, esi
				makebuffExtEdge:
					xor		ecx, ecx
					mov		BSUM, ecx
					mov		RSUM, ecx
					mov		GSUM, ecx
					mov		ecx, dword FHEIGHT
					xor		eax, eax
					countEdgeValues:
						push	ecx
						mov		ecx, eax
						mov		esi, MASKBEGADR
						mul		edx
						add		esi, eax
						mov		eax, ecx
						mov		edi, [ebp+8]
						xor		ebx, ebx
						cmp		esi, edi
						cmovl   eax, ebx
						cmovl   ebx, BTRPT
						add		eax, ebx
						push	eax
						mul		edx
						add		esi, eax
						pop		eax
						mov		ebx, IMGSIZE
						add		edi, ebx
						cmp		esi, edi
						cmovge	esi, PREV
						mov		PREV, esi
						lodsd
						; EBX - CAŁY PIKSEL B-R-G-A
						; push	eax			; EAX - LICZNIK WYSOKOSCI W KOLUMNIE -> STOS

						mov		ebx, eax
						; ADD G VALUE
						and		ebx, 0x00FF0000
						shr		ebx, 16
						add		GSUM, ebx
						; ADD R VALUE
						mov		ebx, eax
						and		ebx, 0x0000FF00
						shr		ebx, 8
						add		RSUM, ebx
						; ADD B RALUE
						mov		ebx, eax
						and		ebx, 0x000000FF
						;shr		edi, 8
						add		BSUM, ebx
						; pop		eax			; EAX - LICZNIK WYSOKOSCI W KOLUMNE <- STOS
						mov		eax, ecx
						inc		eax
						pop		ecx
					loop	countEdgeValues
					
					; DZIELIMY WARTOSCI 
					xor		ebx, ebx
					mov		eax, dword GSUM		; GREEN 
					mov		ecx, dword FHEIGHT
					cdq
					idiv	ecx 
					shl		eax, 16
					and		eax, 0x00FF0000
					or		ebx, eax

					mov		eax, dword RSUM		; RED
					mov		ecx, dword FHEIGHT
					cdq
					idiv		ecx
					shl		eax , 8
					and		eax, 0x0000FF00
					or		ebx, eax
						
					mov		eax, dword BSUM		; BLUE
					mov		ecx, dword FHEIGHT	
					div		ecx
					and		eax, 0x000000FF
					or		eax, ebx

					mov		edi, dword CYCLEBUFF
					stosd		
					;; WYPELNIANIE POCZATKU BUFORA - ROZSZERZANIE KRAWEDZI
					mov		ecx, [ebp+24]
					extLEdgeLoop:
						stosd
					loop	extLEdgeLoop
					
					mov		BUFFPOS, edi
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
					mov		ecx, dword FHEIGHT
					xor		eax, eax
					mov		edx, ROWL
					push	esi				; ESI -> STOS
					makeBuffYLoop:
						push ecx
						mov		ecx, eax
						mov		esi, MASKBEGADR
						mul		edx
						add		esi, eax
						mov		eax, ecx
						mov		edi, [ebp+8]
						xor		ebx, ebx
						cmp		esi, edi
						cmovl   eax, ebx
						cmovl	ebx, BTRPT
						add		eax, ebx						
						push	eax
						mul		edx
						add		esi, eax
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
						lodsd	; EBX - CAŁY PIKSEL B-R-G-A
						;pop		esi
						;push	eax			; EAX - LICZNIK WYSOKOSCI W KOLUMNIE -> STOS

						mov		ebx, eax	
						; ADD G VALUE
						and		ebx, 0x00FF0000
						shr		ebx, 16
						add		GSUM, ebx
						; ADD R VALUE
						mov		ebx, eax
						and		ebx, 0x0000FF00
						shr		ebx, 8
						add		RSUM, ebx
						; ADD G VALUE
						mov		ebx, eax
						and		ebx, 0x000000FF
						;shr		ebx, 8
						add		BSUM, ebx
						
						mov		eax, ecx
						inc		eax
						pop		ecx
					loop	makeBuffYLoop
					pop		esi
					xor		ebx, ebx
					; DZIELIMY WARTOSCI 
					mov		eax, GSUM
					mov		ecx, dword FHEIGHT
					cdq
					idiv	ecx
					shl		eax, 16
					and		eax, 0X00FF0000	
					or		ebx, eax		; Zapisujemy w buforze

					mov		eax, RSUM
					mov		ecx, dword FHEIGHT
					div		ecx
					shl		eax, 8
					and		eax, 0x0000FF00
					or		ebx, eax
					
					mov		eax, BSUM
					mov		ecx, dword FHEIGHT
					;shl		eax, 8
					and		eax, 0x000000FF
					or		eax, ebx
					mov		edi, BUFFPOS
					mov		eax, ebx
					stosd

					mov		BUFFPOS, edi

					pop		ecx
					pop		eax
					sub		ecx, 1
				jnz	makeBuffXLoop

				mov		esi, CYCLEBUFF
				mov		BUFFPOS, esi
				xor		eax, eax
				mov		X, eax
				_hor:
					;; COMPUTE AV VALUES FOR PIXEL
					xor		ebx, ebx
					mov		BSUM, ebx
					mov		RSUM, ebx
					mov		GSUM, ebx
					mov		esi, CYCLEBUFF
					_sumBuff:
						lodsd
						
						mov		ebx, eax	
						; ADD B VALUE
						and		ebx, 0x00FF0000
						shr		ebx, 16
						add		GSUM, ebx
						; ADD R VALUE
						mov		ebx, eax
						and		ebx, 0x0000FF00
						shr		ebx, 8
						add		RSUM, ebx
						; ADD G VALUE
						mov		ebx, eax
						and		ebx, 0x000000FF
						;shr		eax, 8
						add		BSUM, ebx
						cmp		esi, CYCLEBUFFLAST
					jl		_sumBuff

						xor		ebx, ebx
						; DZIELIMY WARTOSCI 
						mov		eax, dword GSUM
						mov		ecx, dword FWIDTH
						cdq
						idiv		ecx
						shl		eax, 16
						and		eax,0x00FF0000
						or		ebx, eax		; Zapisujemy w ebx
						
						mov		eax, dword RSUM
						mov		ecx, dword FWIDTH
						cdq
						idiv	ecx
						shl		eax, 8
						and		eax, 0x0000FF00
						or		ebx, eax
						
						mov		eax, dword BSUM
						mov		ecx, dword FWIDTH
						cdq
						idiv		ecx
						;shl		eax, 8
						and		eax, 0x000000FF
						or		ebx, eax
						
						mov		esi, dword SRCPOS
						lodsd
						and		eax, 0xFF000000
						or		eax, ebx
						
						mov		SRCPOS, esi

						mov	    edi, dword DSTPOS
						;mov		ecx, X
						;shl		ecx, 2
						;mov		eax, Y
						;mov		edx, ROWL
						;mul		edx
						;add		edi, eax
						;add		edi, ecx
						; lea		edi,[ebx+eax+ecx]

						stosd
						mov		DSTPOS, edi
						
						mov		ecx, [ebp+12]
						dec		ecx
						mov		eax, X
						add		eax, [ebp+24]
						cmp		eax, ecx
						jl		addToBuffLoopPROL
							mov		esi, CYCLEBUFFLAST
							mov		eax, [esi]
							mov		edi, BUFFPOS
							stosd
							cmp		edi, CYCLEBUFFLAST
							cmovge	edi, CYCLEBUFF
							mov		BUFFPOS, edi
							jmp		addedToBuff
						;; REPLACE NEXT COLUMN IN BUFFER
						addToBuffLoopPROL:
						mov		esi, MASKBEGADR
						mov		eax, [ebp+24]
						inc		eax
						shl		eax, 2
						add		esi, eax
						;mov		eax, [ebp+28]
						;mov		edx, ROWL
						;mul		edx
						;sub		esi, eax
						mov		ecx, dword FHEIGHT
						xor		eax, eax
						addToBuffYLoop:
							push ecx
							mov		ecx, eax
							mov		esi, MASKBEGADR
							mul		edx
							add		esi, eax
							mov		eax, ecx						
							mov		edi, [ebp+8]
							xor		ebx, ebx
							cmp		esi, edi
							cmovl   eax, ebx
							cmovl	ebx, BTRPT
							add		eax, ebx
							push	eax
							mul		edx
							add		esi, eax
							pop		eax
							mov		ebx, IMGSIZE
							add		edi, ebx
							cmp		esi, edi
							cmovge	esi, PREV
							mov		PREV, esi
							;push	esi
							;lea		esi, [ebx+eax]
							;mov		ebx, [esi]	; EBX - CAŁY PIKSEL B-R-G-A
							;pop		esi
							; push	eax			; EAX - LICZNIK WYSOKOSCI W KOLUMNIE -> STOS
							lodsd

							mov		ebx, eax	
							; ADD G VALUE
							and		ebx, 0x00FF0000
							shr		ebx, 16
							add		GSUM, ebx
							; ADD R VALUE
							mov		ebx, eax
							and		ebx, 0x0000FF00
							shr		ebx, 8
							add		RSUM, ebx
							; ADD G VALUE
							mov		ebx, eax
							and		ebx, 0x000000FF
							;shr		edi, 8
							add		GSUM, ebx
							
							mov		eax, ecx
							;sub		eax, BTRPT
							inc		eax
							pop		ecx
						loop	addToBuffYLoop
						; DZIELIMY WARTOSCI
						
						mov		eax, GSUM
						mov		ecx, dword FHEIGHT
						cdq
						idiv		ecx
						shl		eax, 16
						and		eax, 0X00FF0000	
						or		ebx, eax		; Zapisujemy w buforze

						mov		eax, RSUM
						mov		ecx, dword FHEIGHT
						cdq
						idiv		ecx
						shl		eax, 8
						and		eax, 0x0000FF00
						or		ebx, eax
					
						mov		eax, GSUM
						mov		ecx, dword FHEIGHT
						;shl		eax, 8
						and		eax, 0x000000FF
						or		eax, ebx
						mov		edi, BUFFPOS
						stosd
						
						cmp		edi, CYCLEBUFFLAST
						cmovg	edi, CYCLEBUFF
						mov		edi, BUFFPOS
						mov		BUFFPOS, edi
						
						addedToBuff:
						mov		eax, X
						inc		eax
						mov		X, eax
						mov		ecx, [ebp+12]
						cmp		eax, ecx
						jl		_hor
				mov		eax, Y
				inc		eax
				mov		Y, eax
				mov		ecx, [ebp+16]
				cmp		eax, ecx
				jl		_vert


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

getPixel:
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
