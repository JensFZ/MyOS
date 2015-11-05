global loader ; make loader visible for the linker
extern main   ; main function of the C kernel

FLAGS		equ 0
MAGIC   	equ 0x1BADB002		; Magicnumber for Grub
CHECKSUM	equ -(MAGIC+FLAGS) 	; Checksum

section .text
align 4
MultiBootHeader:
  dd MAGIC
  dd FLAGS
  dd CHECKSUM

loader:
  mov esp, 0x200000 	; Set stack to 2MB
  push eax		; Multiboot Magicnumber pushed to stack
  push ebx		; push Multiboot structure address to stack
  call main		; call C kernel main function

  cli			; if kernel reaches this point -> halt CPU
  hlt
