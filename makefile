PROJ=test
ASRC=proj1.asm
CSRC=proj.c

AS=nasm
CC=gcc
LD=gcc

AOBJ=$(ASRC:.asm=.o)
COBJ=$(CSRC:.c=.o)

default: $(PROJ)

$(PROJ): $(AOBJ) $(COBJ)
	$(LD) -m32 -g $(AOBJ) $(COBJ) -o	$@

%.o: %.asm
	$(AS) -felf -g -l proj1.lst -o $@	$<

%.o: %.c
	$(CC) -Wall -m32 -g -c -o $@	$<

clean:
	rm -f $(AOBJ) $(COBJ) $(PROJ)
