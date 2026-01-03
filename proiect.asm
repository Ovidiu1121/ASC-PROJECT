ASSUME cs:code, ds:data

data SEGMENT
    BUFMAX  EQU 64
    inbuf   db BUFMAX, 0, BUFMAX dup(0)

    sir     db 16 dup(?)
    len     db 0
    C       dw ?
data ENDS

code SEGMENT
start:
    mov ax, data
    mov ds, ax
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
    jb  Finish
    xor al, al
    lea si, sir
    mov cl, len
    xor ch, ch
SumLoop:
    add al, [si]
    inc si
    loop SumLoop
    mov ah, al

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

    mov C, ax
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
    mov C, dx

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

BitLoop:
    shr al, 1
    adc ah, 0
    loop BitLoop

    mov al, ah
    pop cx
    ret
CountBits ENDP

code ENDS
END start
