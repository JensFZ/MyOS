org 0x7C00 ; 
bits 16 ; 16-Bit design

%define ENDL 0x0D, 0x0A ; Newline + Character Return

;
; BIOS Parameter Block
;
jmp short start ; Jump to start
nop; 1 byte nop

bdb_oem: db 'MyOS    ' ; OEM Name
dbd_bytes: dw 512 ; Bytes per Sector
dbd_sectors: db 1 ; Sectors per Cluster
dbd_reserved: dw 1 ; Reserved Sectors
dbd_fats: db 2 ; Number of FATs
dbd_root_entries: dw 0E0h ; Number of Root Directory Entries
dbd_sectors_small: dw 2880 ; Number of Sectors (if dbd_sectors == 0)
dbd_media: db 0xf0 ; Media Descriptor
dbd_sectors_per_fat: dw 9 ; Sectors per FAT
dbd_sectors_per_track: dw 18 ; Sectors per Track
dbd_heads: dw 2 ; Number of Heads
dbd_hidden: dd 0 ; Number of Hidden Sectors
dbd_sectors_large: dd 0 ; Number of Sectors (if dbd_sectors_small == 0)


;
; Extended boot record
;
ebr_drive: db 0 ; Drive Number
ebr_reserved: db 0 ; Reserved
ebr_signature: db 29h ; Extended Boot Record Signature
ebr_volume_id: dd 0 ; Volume ID
ebr_volume_label: db 'MYOS BOOT ', 0 ; Volume Label
ebr_filesystem: db 'FAT12   ' ; Filesystem Type


;
; Code startet hier
;


start:
  jmp main

; Schreibt ein String auf den Bildschirm
; Params:
;   - ds:si zeigt auf String

puts:
  push si
  push ax

.loop: ; Loop für puts
  lodsb       ; Lädt nächstes zeichen in al
  or al, al   ; prüfen, ob nächstes Zeichen null ist
  jz .done

  mov ah, 0x0e
  mov bh, 0
  int 0x10

  jmp .loop

.done:
  pop ax
  pop si
  ret

main:

  ; Setup data

  mov ax, 0    ; es kann nicht direkt in ds und es geschrieben werden
  mov ds, ax
  mov es, ax


  ;setup stack
  mov ss, ax
  mov sp, 0x7C00 ; Stack wächst nach unten -> liegt unterhalb dieses Blocks

  mov si, msg_hello
  call puts


  hlt ;

.halt: ; HALT
  jmp .halt


msg_hello: db 'Welcome to MyOS', ENDL, 0

times 510-($-$$) db 0 ; 510 - (aktuelle Position - aktuelle sektion) mit 0 auffüllen -> immer 512 bytes 

dw 0AA55h