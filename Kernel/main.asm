org 0x7C00 ; 
bits 16 ; 16-Bit design

%define ENDL 0x0D, 0x0A ; Newline + Character Return

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


msg_hello: db 'Welcome to MyOS-Kernel', ENDL, 0

times 510-($-$$) db 0 ; 510 - (aktuelle Position - aktuelle sektion) mit 0 auffüllen -> immer 512 bytes 

dw 0AA55h