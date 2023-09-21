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
ebr_volume_label: db 'MYOS BOOT ' ; Volume Label
ebr_filesystem: db 'FAT12   ' ; Filesystem Type


;
; Code startet hier
;


start:
   ; Setup data

  mov ax, 0    ; es kann nicht direkt in ds und es geschrieben werden
  mov ds, ax
  mov es, ax


  ;setup stack
  mov ss, ax
  mov sp, 0x7C00 ; Stack wächst nach unten -> liegt unterhalb dieses Blocks

  ; Bugfix für ein BIOS, was uns nach 07C0:0000, anstelle von 0000:7C00 lädt
  push es
  push word .after
  retf ; return far -> springt zu .after

.after:

  mov [ebr_drive], dl ; dl = drive number
  
  mov si, msg_hello
  call puts

  ; lese drive parameter
  push es
  mov ah, 08h
  int 13h

  jc floppy_error
  pop es

  and cl, 0x3f ; cl = cl & 0x3f -> nur die ersten 6 bits von cl sind gültig
  xor ch, ch ; ch = 0
  mov [dbd_sectors_per_track], cx ; cx = cl + ch * 256

  inc dh ; dh = 0
  mov [dbd_heads], dh ; dh = dh + 1

  ; root diektory entries (reserved sectors + sectors per track * number of fats)
  mov ax, [dbd_sectors_per_fat] ; ax = dbd_sectors_per_fat
  mov bl, [dbd_fats]              ; bl = dbd_fats
  xor bh, bh                      ; bh = 0
  mul bx                          ; ax = ax * bx
  add ax, [dbd_reserved]          ; ax = ax + dbd_reserved
  push ax                         ; ax auf stack                   
  
  ; größe des root directory = (32 * dbd_root_entries) / dbd_bytes
  mov ax, [dbd_root_entries]   ; ax = dbd_sectors_per_fat
  shl ax, 5                       ; ax = ax * 32
  xor dx, dx                      ; dx = 0
  div word [dbd_bytes]            ; ax = ax / dbd_bytes, dx = ax % dbd_bytes

  test dx, dx                     ; dx == 0?
  jz .root_dir_after              ; wenn ja, dann root_dir_after
  inc ax                          ; ax = ax + 1

.root_dir_after:
  ; lesse root directory
  mov cl, al                     ; cl = anzahl der sektoren = größe des root directory
  pop ax                          ; ax = LBA des root directorys
  mov dl, [ebr_drive]             ; dl = drive number
  mov bx, buffer                  ; es:bx = buffer
  call disk_read                  ; lese root directory

  ; suche nach kernel.bin
  xor bx, bx                      ; bx = 0
  mov di, buffer                  ; di = buffer

.search_kernel:
  mov si, file_kernel_bin         ; si = file_kernel_bin
  mov cx, 11                      ; cx = 11
  push di                         ; di auf stack
  repe cmpsb                      ; vergleiche si und di
  pop di                          ; di vom stack
  je .found_kernel                 ; wenn gleich, dann found_kernel

  add di, 32                      ; di = di + 32
  inc bx                          ; bx = bx + 1
  cmp bx, [dbd_root_entries]      ; bx == dbd_root_entries?
  jl .search_kernel               ; wenn nicht, dann search_kernel
  jmp kernel_not_found_error      ; wenn nicht gefunden, dann kernel_not_found_error

.found_kernel:

  ; di hat die adresse des kernel.bin eintrags
  mov ax, [di + 26]              ; ax = di + 26
  mov [kernel_cluster], ax       ; kernel_lba = ax

  ; lade FAT in memory
  mov ax, [dbd_reserved]         ; ax = dbd_reserved
  mov bx, buffer                 ; es:bx = buffer
  mov cl, [dbd_sectors]          ; cl = dbd_sectors
  mov dl, [ebr_drive]            ; dl = drive number
  call disk_read                 ; lese FAT

  ; lese kernel.bin
  mov bx, KERNEL_LOAD_SEGMENT    ; es:bx = KERNEL_LOAD_SEGMENT
  mov es, bx
  mov bx, KERNEL_LOAD_OFFSET     ; bx = KERNEL_LOAD_OFFSET

.load_kernel_loop:
  ; lese nächsten cluster
  mov ax, [kernel_cluster]       ; ax = kernel_cluster
  add ax, 31                     ; ax = ax + 31 (fix für jetzt -> muss in der zukunft berechnet werden)

  mov cl, 1
  mov dl, [ebr_drive]
  call disk_read

  add bx, [dbd_bytes]            ; bx = bx + dbd_bytes
  
  ; berechne nächsten cluster

  mov ax, [kernel_cluster]       ; ax = kernel_cluster
  mov cx, 3                     ; cx = 3
  mul cx                         ; ax = ax * cx
  mov cx, 2                     ; cx = 2
  div cx                         ; ax = ax / cx, dx = ax % cx
  
  mov si, buffer
  add si, ax
  mov ax, [ds:si]               ; ax = [ds:si]

  or dx,dx                      ; dx == 0?
  jz .even                      ; wenn ja, dann even

.odd:
  shr ax, 4                     ; ax = ax >> 4
  jmp .next_cluster_after

.even:
  and ax, 0x0FFF                ; ax = ax & 0x0FFF

.next_cluster_after:
  cmp ax, 0x0FF8                ; ax == 0x0FF8?
  jae .read_finish

  mov [kernel_cluster], ax      ; kernel_cluster = ax
  jmp .load_kernel_loop

.read_finish:
  mov dl, [ebr_drive]           ; dl = drive number

  mov ax, KERNEL_LOAD_SEGMENT   ; es:bx = KERNEL_LOAD_SEGMENT
  mov ds, ax
  mov es, ax

  jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

  jmp wait_key_and_reboot


  cli ; Interrupts deaktivieren
  hlt ; HALT

floppy_error:
  mov si, floppy_error_msg
  call puts
  jmp wait_key_and_reboot
  hlt

kernel_not_found_error:
  mov si, kernel_not_found_error_msg
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

.fail:
  jmp floppy_error

.success:
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


msg_hello:                  db 'Lade MyOS', ENDL, 0
floppy_error_msg:           db 'Floppy error', ENDL, 0
kernel_not_found_error_msg: db 'KERNEL not found', ENDL, 0
file_kernel_bin:            db 'KERNEL  BIN'
kernel_cluster:             dw 0

KERNEL_LOAD_SEGMENT         equ 0x2000
KERNEL_LOAD_OFFSET          equ 0x0000

times 510-($-$$) db 0 ; 510 - (aktuelle Position - aktuelle sektion) mit 0 auffüllen -> immer 512(eigentlich 510, da noch zwei byte kommen) bytes 

dw 0AA55h


buffer: