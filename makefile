ASM=nasm

BOOT_DIR=Bootsektor
BUILD_DIR=build

$(BUILD_DIR)\main_floppy.img: $(BUILD_DIR)\bootloader.bin
	copy $(BUILD_DIR)\bootloader.bin $(BUILD_DIR)\main_floppy.img


$(BUILD_DIR)\bootloader.bin: $(BOOT_DIR)\bootloader.asm 
	$(ASM) $(BOOT_DIR)\bootloader.asm -f bin -o $(BUILD_DIR)\bootloader.bin