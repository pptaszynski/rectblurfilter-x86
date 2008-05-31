%define	FWIDTH		[ebp-4]
%define FHEIGHT		[ebp-8]
%define IMGSIZE		[ebp-12]
%define CYCLEBUFF	[ebp-16]
%define CYCLEBUFFLAST	[ebp-20]

extern _filter
extern _malloc
extern _free

	section .text
	
;
;	Argumenty wywolania:
;
;	[ebp+8]		*src
;	[ebp+12]	widht		
;	[ebp+16]	height
;	[ebp+20]	dest
;	[ebp+24]	fwidth
;	[ebp+28]	fheight
;


