BUILD_DIR?=build
ASM ?= nasm

.PHNONY: all clean

all: stage1

stage1: $(BUILD_DIR)\stage1.bin

$(BUILD_DIR)\stage1.bin:
	$(ASM) bootloader.asm -f bin -o ..\..\$(BUILD_DIR)\stage1.bin

clean:
	rd /s /q $(BUILD_DIR)
