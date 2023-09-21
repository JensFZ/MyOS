org 0x0 ; 
bits 16 ; 16-Bit design

%define ENDL 0x0D, 0x0A ; Newline + Character Return

start:
  mov si, msg_hello
  call puts

.halt: ; HALT
  cli
  hlt ;



puts:
  push si
  push ax
  push bx

.loop: ; Loop für puts
  lodsb       ; Lädt nächstes zeichen in al
  or al, al   ; prüfen, ob nächstes Zeichen null ist
  jz .done

  mov ah, 0x0e
  mov bh, 0
  int 0x10

  jmp .loop

.done:
  pop bx
  pop ax
  pop si
  ret

msg_hello: db 'Welcome to MyOS-Kernel', ENDL, 0