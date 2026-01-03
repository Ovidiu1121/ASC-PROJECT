ASSUME cs:code, ds:data

data SEGMENT
    BUFMAX  EQU 64
    inbuf   db BUFMAX, 0, BUFMAX dup(0)

    sir     db 16 dup(?)
    len     db 0
    C       dw ?
    msgInput db 'Introduceti octetii in format hex: $'
    msgSorted db 0Dh, 0Ah, 'Sirul sortat: $'  ;0Dh, 0Ah = enter (linie noua)
    msgC      db 0Dh,0Ah,'Cuvantul C calculat: $'
    msgRotate db 0Dh,0Ah,'Sirul dupa rotiri: $'
data ENDS

code SEGMENT
start:
    mov ax, data
    mov ds, ax
    
    lea dx, msgInput ;mesaj
    call PrintString

    mov ah, 0Ah
    lea dx, inbuf
    int 21h

    lea si, inbuf+2
    mov cl, inbuf[1]
    xor ch, ch

    lea di, sir
    xor bl, bl

ParseNext:
    cmp cx, 0
    je  DoneParse
    cmp bl, 16
    je  DoneParse

SkipJunk:
    cmp cx, 0
    je  DoneParse
    mov al, [si]
    cmp al, ' '
    je  SkipOne
    cmp al, '$'
    je  SkipOne
    cmp al, ','
    je  SkipOne
    jmp NeedTwoHex

SkipOne:
    inc si
    dec cx
    jmp SkipJunk

NeedTwoHex:
    cmp cx, 2
    jb  DoneParse

    mov al, [si]
    call HexToNibble
    jc  DoneParse
    shl al, 4
    mov ah, al

    inc si
    dec cx

    mov al, [si]
    call HexToNibble
    jc  DoneParse
    or  al, ah

    mov [di], al
    inc di
    inc bl

    inc si
    dec cx
    jmp ParseNext

DoneParse:
    mov len, bl

    cmp bl, 8
    jae ContinueProgram   ; condiția inversă
    jmp Finish            ; salt NEAR (fără limită)
    ContinueProgram:
    xor al, al
    lea si, sir
    mov cl, len
    xor ch, ch
SumLoop:
    add al, [si]
    inc si
    loop SumLoop
   
    lea si, sir
    mov dl, [si]
    and dl, 0Fh

    mov cl, len
    xor ch, ch
    lea si, sir
    add si, cx
    dec si
    mov al, [si]
    shr al, 4
    and al, 0Fh
    xor dl, al

    xor bh, bh
    lea si, sir
    mov cl, len
    xor ch, ch
OrLoop:
    mov al, [si]
    shr al, 2
    and al, 0Fh
    or  bh, al
    inc si
    loop OrLoop

    mov al, bh
    shl al, 4
    or  al, dl

    mov word ptr C, ax
    mov cl, len
    dec cl
OuterSort:
    push cx
    lea si, sir
    mov cl, len
    xor ch, ch
    dec cx

InnerSort:
    mov al, [si]
    mov ah, [si+1]
    cmp al, ah
    jae NoSwap

    mov [si], ah
    mov [si+1], al

NoSwap:
    inc si
    dec cx
    jnz InnerSort
    pop cx
    dec cx
    jnz OuterSort

    lea dx, msgSorted ;mesaj
    call PrintString

    lea si, sir
    mov cl, len
    xor ch, ch

    xor bh, bh
    xor bl, bl
    xor dl, dl

CheckNext:
    mov al, [si]
    call CountBits

    cmp al, 3
    jbe SkipElem

    cmp al, bh
    jbe SkipElem

    mov bh, al
    mov dl, bl

SkipElem:
    inc si
    inc bl
    loop CheckNext

    inc dl
    xor dh, dh
    mov word ptr C, dx
    
    lea dx, msgC ;mesaj
    call PrintString

    mov al, byte ptr C+1 ;byte superior
    call PrintHexByte
    mov al, byte ptr C   ;byte inferior
    call PrintHexByte  ;afisam C in hex
	
    mov dl, ' ' ;spatiu intre hex si binar
    call PrintChar

    mov al, byte ptr C+1  ;byte superior
    call PrintBinaryByte
    mov al, byte ptr C    ;byte inferior
    call PrintBinaryByte
    
    ; ENTER
    mov dl, 0Dh
    call PrintChar
    mov dl, 0Ah
    call PrintChar

;rotirea fiecarui octet:
    lea si, sir ;si=inceputul sirului de octeti
    mov cl, len ;cl=nr de octeti
    xor ch,ch   ;cx=contor pentru bucla

RotateLoop: 
    mov al, [si] ;octetul curent din sir

    ;calcul N=suma primilor 2 biti
    mov bl, al ;copiem octetul in bl
    and bl, 00000011b ;pastram doar bitul 0 si bitul 1, BL=N
   
    push cx  ;salvam contorul
    mov cl, bl
    rol al, cl     ;rotire circulara la stanga cu N pozitii
    pop cx    ;refacem contorul

    mov [si], al      ;salvam rezultatul 
    inc si   ;trecem la urmatorul octet 
    loop RotateLoop 
lea dx, msgRotate
call PrintString ;mesaj

;afisarea octetilor (pentru fiecare se afiseaza hex si bina/r)
lea si, sir
mov cl, len
xor ch, ch 

ShowLoop:
    mov al, [si]  ;al=octetul curent

    call PrintHexByte ;afiseaza octetul din AL in hex
    mov dl, ' '       ;spatiu intre hex si binar
    call PrintChar    

    mov al, [si]   ;reincarcam octetul
    call PrintBinaryByte ;afisarea in binar

    mov dl, 0Dh
    call PrintChar
    mov dl, 0Ah
    call PrintChar ;trecem la linie noua

    inc si  ;trecem la urmatorul octet de afisat
    loop ShowLoop


Finish:
    mov ax, 4C00h
    int 21h
HexToNibble PROC
    cmp al, '0'
    jb  HBad
    cmp al, '9'
    jbe HDigit

    cmp al, 'A'
    jb  HLowerCheck
    cmp al, 'F'
    jbe HUpper

HLowerCheck:
    cmp al, 'a'
    jb  HBad
    cmp al, 'f'
    jbe HLower
    jmp HBad

HDigit:
    sub al, '0'
    clc
    ret

HUpper:
    sub al, 'A'
    add al, 10
    clc
    ret

HLower:
    sub al, 'a'
    add al, 10
    clc
    ret

HBad:
    stc
    ret
HexToNibble ENDP

CountBits PROC
    push cx
    mov cl, 8
    xor ah, ah

CountBitLoop:
    shr al, 1
    adc ah, 0
    loop CountBitLoop

    mov al, ah
    pop cx
    ret
CountBits ENDP

PrintChar PROC ;afisarea unui caracter ASCII 
    mov ah, 02h
    int 21h
    ret
PrintChar ENDP

PrintHexByte PROC  ;afisarea unui octet in hex
   push ax ;salvam AX
   push dx ;salvam DX

   mov ah, al ;mutam octetul in ah
   shr ah, 4 ;deplasam la dreapta 4 pozitii (mutam nibble-ul superior jos)
   mov al, ah  ;AL=nibble
   call NibbleToHex ;convertim 
   mov dl, al
   call PrintChar ;afisam caracterul hex

   pop dx
   pop ax ;refacem registrele

   and al, 0Fh ;pastram nibble ul inferior 
   call NibbleToHex

   mov dl, al
   call PrintChar ;afisam al doilea caracter hex

   ret
PrintHexByte ENDP

NibbleToHex PROC ;conversie nibble -> caracter
   cmp al, 9
   jbe Digit

   add al, 'A' - 10
   ret

Digit:
   add al, '0'
   ret
NibbleToHex ENDP

PrintBinaryByte PROC
   push ax
   push bx
   push cx
   push dx

   mov bl, al
   mov cx, 8

BitLoop:
   shl bl, 1
   jc BitOne
   mov dl, '0'
   jmp PrintBit

BitOne:
   mov dl, '1'

PrintBit:
   call PrintChar
   loop BitLoop
   pop dx
   pop cx
   pop bx
   pop ax
   ret
PrintBinaryByte ENDP

PrintString PROC ;afisarea unui mesaj
   mov ah, 09h
   int 21h
   ret
PrintString ENDP
code ENDS
END start
