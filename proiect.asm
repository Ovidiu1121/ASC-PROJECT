;-----SEGMENTUL DE DATE-----
ASSUME cs:code, ds:data

data SEGMENT
    BUFMAX  EQU 64 ; dimensiune maximă buffer input
    ; buffer DOS pentru citire cu int 21h/ AH=0Ah
    ; [0] = dim max
    ; [1] = nr. caractere citite
    ; [2...] = caracterele introduse 

    inbuf   db BUFMAX, 0, BUFMAX dup(0)

    sir     db 16 dup(?); sirul de octeti maxim 16
    len     db 0; lungimea sirului
    C       dw ?; cuvantul C calculat

    ;------Mesaje pentru afisare-----
    msgInput db 'Introduceti octetii in format hex: $'
    msgSorted db 0Dh, 0Ah, 'Sirul sortat: $'  ;0Dh, 0Ah = enter (linie noua)
    msgPos db 0Dh,0Ah,'Pozitia octetului cu cei mai multi biti 1: $'
    msgC      db 0Dh,0Ah,'Cuvantul C calculat: $'
    msgRotate db 0Dh,0Ah,'Sirul dupa rotiri: $'
data ENDS

;----CODUL----
code SEGMENT
start:
    mov ax, data
    mov ds, ax
    
    ;----Afisare mesaj input---
    lea dx, msgInput 
    call PrintString

    ;---Citire input(int 21h, AH = 0Ah)
    mov ah, 0Ah
    lea dx, inbuf
    int 21h

    ;---Parsare si conversie HEX - BINAR---
    lea si, inbuf+2; si = primul caracter citit
    mov cl, inbuf[1]; cl = nr. de caractere
    xor ch, ch

    lea di, sir; di = inceputul sirului
    xor bl, bl; bl = nr. de octeti cititi

ParseNext:
    cmp cx, 0
    je  DoneParse
    cmp bl, 16; maxim 16 octeti
    je  DoneParse

;---sarim peste separatori---
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

;---citim 2 caractere hex---
NeedTwoHex:
    cmp cx, 2
    jb  DoneParse

    mov al, [si]
    call HexToNibble; conversie hex-nibble
    jc  DoneParse
    shl al, 4; nibble superior
    mov ah, al

    inc si
    dec cx

    mov al, [si]
    call HexToNibble
    jc  DoneParse
    or  al, ah; formam octetul complet

    mov [di], al; salvam octetul
    inc di
    inc bl

    inc si
    dec cx 
    jmp ParseNext

DoneParse:
    mov len, bl; salvam lungimea sirului

    ;---VERIFICARE MINIM 8 OCTETI---
    cmp bl, 8
    jae ContinueProgram   ; dacă avem >=8 octeți, continuăm
    jmp Finish            ; altfel ieșim din program

ContinueProgram:

;---CALCULUL CUVANTULUI C---

;---PAS 3: suma octetilor modulo 256---
    xor al, al
    lea si, sir
    mov cl, len
    xor ch, ch
SumLoop:
    add al, [si]
    inc si
    ;loop SumLoop
    dec cx
    jnz SumLoop
    mov ah, al

;---PAS 1: XOR intre nibble inferior de la primul octet si nibble superior de la ultimul octet
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

;---PAS 2: OR intre bitii 2-5 ai tuturor octetilor
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
    ;loop OrLoop
    dec cx
    jnz OrLoop

    mov al, bh
    shl al, 4
    or  al, dl

    mov C, ax; C final

;---SORTARE DESCRESCATOARE (Bubble Sort)---
    mov cl, len
    dec cl
OuterSort:
    lea si, sir
    mov ch, cl

InnerSort:
    mov al, [si]
    mov ah, [si+1]
    cmp al, ah
    jae NoSwap

    mov [si], ah
    mov [si+1], al

NoSwap:
    inc si
    dec ch
    jnz InnerSort
    dec cl
    jnz OuterSort

;---AFISARE SIR SORTAT---
lea dx, msgSorted
call PrintString

lea si, sir
mov cl, len
xor ch, ch

PrintSortedLoop:
    mov al, [si]
    call PrintHexByte
    mov dl, ' '
    call PrintChar

    inc si
    dec cx
    jnz PrintSortedLoop

;---DETERMINARE OCTET CU MAXIM DE BITI1 (>3)
    lea si, sir
    mov cl, len
    xor ch, ch

    xor bh, bh; max biti
    xor bl, bl; index curent
    xor dl, dl; pozitie

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
    dec cx
    jnz CheckNext
    ;loop CheckNext

    inc dl
    push dx

    lea dx, msgPos
    call PrintString

    pop dx
    add dl, '0'        ; conversie cifră → ASCII
    call PrintChar

    xor dh, dh

;---AFISARE C (HEX + BINAR)---
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

;---ROTIREA FIECARUI OCTET---
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
    dec cx
    jnz RotateLoop 

;---AFISARE SIR DUPA ROTIRI---
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
    dec cx 
    jnz ShowLoop


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

    mov bl, al        ; salvăm octetul
    mov cx, 8

BitLoop:
    shl bl, 1         ; MSB → CF
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
