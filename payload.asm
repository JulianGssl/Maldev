bits 64
section .data
    message db "INFECTED", 0xA      ; Message à afficher, suivi d'un saut de ligne
    message_len equ $ - message  ; Longueur du message

section .text
global _start
_start:
    ; Appel système write (syscall 1)
    mov rax, 1                  ; Numéro du syscall pour write
    mov rdi, 1                  ; Descripteur de fichier pour stdout
    lea rsi, [rel message]      ; Adresse du message
    mov rdx, message_len        ; Longueur du message
    syscall

    ; Appel système exit (syscall 60)
    mov rax, 60                 ; Numéro du syscall pour exit
    xor rdi, rdi                ; Code de retour 0
    syscall

    jmp short payload_end       ; jmp relatif pour pouvoir exécuter ensuite le code originel du binaire

payload_end:                    ; Vide en attente de l'écriture de l'adresse de retour

;nasm -f bin -o payload.bin payload.asm
;xxd -i payload.bin > payload.hex
