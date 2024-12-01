ASM      := nasm
ASMFLAGS := -f elf64 -g
LD       := ld

all: src/main.asm
	$(ASM) $(ASMFLAGS) src/main.asm -o main.o
	$(LD) main.o -o main
	rm main.o

.PHONY: all clean

clean:
	rm main
