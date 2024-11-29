ASM      := nasm
ASMFLAGS := -f elf64 -g
LD       := ld
SOURCES  := $(wildcard src/%.asm)
TARGETS  := $(patsubst src/%.asm, %, $(SOURCES))

all: $(TARGETS)

%: src/%.asm
	$(ASM) $(ASMFLAGS) $< -o $@.o
	$(LD) $@.o -o $@
	rm $@.o

.PHONY: all clean

clean:
	rm -f $(TARGETS)
