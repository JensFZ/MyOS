ASM=nasm
CC=gcc	
BUILD_DIR=build
TOOLS_DIR=tools

.PHNONY: all floppy_image kernel bootloader clean always run debug tools_fat

all: floppy_image tools_fat

#
# Floppy Image
#
floppy_image: $(BUILD_DIR)\main_floppy.img
$(BUILD_DIR)\main_floppy.img: bootloader kernel
	wsl dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img bs=512 count=2880
	wsl mkfs.fat -F 12 -n "MyOS" $(BUILD_DIR)/main_floppy.img
	wsl dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/main_floppy.img conv=notrunc
	wsl mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/kernel.bin "::kernel.bin"
	wsl mcopy -i $(BUILD_DIR)/main_floppy.img test.txt "::test.txt"

#
# Bootloader
#
bootloader: $(BUILD_DIR)\bootloader.bin
$(BUILD_DIR)\bootloader.bin: always
	$(ASM) Bootsektor\bootloader.asm -f bin -o $(BUILD_DIR)\bootloader.bin

#
# Kernel
#
kernel: $(BUILD_DIR)\kernel.bin
$(BUILD_DIR)\kernel.bin: always
	$(ASM) Kernel\main.asm -f bin -o $(BUILD_DIR)\kernel.bin

#
# Tools FAT
#
tools_fat: $(BUILD_DIR)\tools\fat.exe
$(BUILD_DIR)\tools\fat.exe: always $(TOOLS_DIR)\fat\fat.c
	if not exist $(BUILD_DIR)\tools mkdir -p $(BUILD_DIR)\tools
	$(CC) -g -o $(BUILD_DIR)\tools\fat.exe tools\fat\fat.c
#
# Always
#
always:
	if not exist $(BUILD_DIR) mkdir -p $(BUILD_DIR)

#
# Clean
#
clean:
	rd /s /q $(BUILD_DIR)

#
# Run
#
run: floppy_image
	qemu-system-i386 -fda $(BUILD_DIR)/main_floppy.img

#
# Debug
#
debug: floppy_image
	bochsdbg -f bochs_config -q