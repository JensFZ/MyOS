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

  mov [ebr_drive], dl ; dl = drive number
  mov ax, 1
  mov cl, 1
  mov bx, 0x7E00 ; 0x7E00 = 0x7C00 + 512 -> Nach dem Bootsektor
  call disk_read


  cli ; Interrupts deaktivieren
  hlt ; HALT

floppy_error:
  mov si, floppy_error_msg
  call puts
  jmp wait_key_and_reboot
  hlt

wait_key_and_reboot:
  mov ah, 0
  int 16h ; warte auf keypress
  jmp 0FFFFh:0 ; reboot
  hlt

.halt: ; HALT
  cli ; Interrupts deaktivieren
  hlt ; HALT


;
; Disk Routinen
;

;
; Konvertiert LBA zu CHS
; Params:
;   - ax: LBA Adresse
; Returns:
;   - cx [bits 0-5]: sector
;   - cx [bits 6-15]: cylinder
;   - dx: head

lba_to_chs:
  push ax
  push dx

  xor dx, dx ; dx = 0
  div word [dbd_sectors_per_track] ; ax / dbd_sectors_per_track -> dx = Rest, ax = Ergebnis
  inc dx; dx = dx + 1
  mov cx, dx ; cx = dx

  xor dx, dx ; dx = 0
  div word [dbd_heads] ; ax / dbd_heads -> dx = Rest, ax = Ergebnis
  mov dh, dl ; dh = head

  mov ch, al ; ch = cylinder
  shl ah, 6 ; ah * 64
  or cl, ah ; cl = cl + ah

  pop ax
  mov dl, al ; restore DL
  pop ax
  ret

;
; Liest einen Sektor von der Disk
; Params:
;   - ax: LBA sector
;   - cl: nummer des sektors
;   - dl: drive
;   -es:bx: adresse, wo der sektor gespeichert werden soll
disk_read:

  push ax
  push bx
  push cx 
  push dx
  push di

  push cx
  call lba_to_chs
  pop ax

  mov ah, 02h
  mov di, 3
.retry:
  pusha; alle register auf stack
  stc ; set carry flag
  int 13h
  jnc .success

  popa ; alle register vom stack
  call disk_reset

  dec di
  test di, di
  jnz .retry

.fail
  jmp floppy_error

.success
  popa

  pop di
  pop dx
  pop cx
  pop bx
  pop ax  

  ret


;
; Resetet die Disk
; Params:
;   - dl: drive
disk_reset:
  pusha
  mov ah, 0
  stc
  int 13h
  jc floppy_error
  popa
  ret


msg_hello: db 'Welcome to MyOS', ENDL, 0
floppy_error_msg: db 'Floppy error', ENDL, 0

times 510-($-$$) db 0 ; 510 - (aktuelle Position - aktuelle sektion) mit 0 auffüllen -> immer 512 bytes 

dw 0AA55h