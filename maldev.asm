section .data
    no_pt_note_msg db "No PT_NOTE found", 0xA, 0  ; Message d'erreur + saut de ligne
    pt_note_found_msg db "PT_NOTE found", 0xA, 0 ; Message de succès + saut de ligne
    pt_note_modified_msg db "PT_NOTE converted to PT_LOAD and saved", 0xA, 0
    modification_failed_msg db "Failed to convert PT_NOTE", 0xA, 0
    elf_file db "CopySafeBinary", 0                   ; Nom du fichier ELF

section .bss
    buffer resb 64                  ; Tampon pour lire l'en-tête ELF
    phdr_buffer resb 56             ; Taille d'un PHDR (64 bits)
    fd resd 1                       ; Descripteur de fichier
    bytes_read resd 1               ; Nombre d'octets lus  
    iter_count resd 1       

section .text
global _start

_start:
    ; Ouvrir le fichier ELF en lecture/écriture
    mov rdi, elf_file              ; Nom du fichier
    mov rsi, 2                     ; O_RDWR
    mov rax, 2                     ; syscall: open
    syscall
    mov [fd], eax                  ; Sauvegarder le descripteur de fichier

    ; Vérifier si le fichier a été ouvert avec succès
    test eax, eax
    js error_exit                  ; Quitter en cas d'erreur

    ; Lire l'en-tête ELF
    mov rdi, [fd]                  ; Descripteur de fichier
    xor rsi, rsi
    mov rsi, buffer                ; Tampon pour stocker l'en-tête ELF
    mov rdx, 64                    ; Taille de l'en-tête ELF
    mov rax, 0                     ; syscall: read
    syscall
    mov [bytes_read], eax          ; Sauvegarder le nombre d'octets lus

    ; Vérifier si suffisamment d'octets ont été lus
    cmp eax, 64
    jl error_exit                  ; Quitter si la lecture est insuffisante

    ; Lire l'offset et le nombre de phdrs
    mov rbx, [buffer + 0x20]          ; e_phoff (offset de la table des phdrs)
    movzx rax, word [buffer + 0x38]          ; e_phnum (nombre de phdrs)

    ; Positionner le fichier à e_phoff
    mov rdi, [fd]                  ; Descripteur de fichier
    mov rax, 8                     ; syscall: lseek
    mov rsi, rbx                   ; Offset e_phoff
    xor rdx, rdx                   ; SEEK_SET
    syscall

    ; Boucle pour chercher PT_NOTE
    xor rdx, rdx                   ; Réinitialiser l'index de boucle
find_pt_note:
    cmp [iter_count], rcx          ; Comparer l'index avec e_phnum
    jge no_pt_note                 ; S'il n'y a pas de PT_NOTE, afficher une erreur

    ; Lire un PHDR
    mov rdi, [fd]                  ; Descripteur de fichier
    mov rsi, phdr_buffer           ; Tampon pour le PHDR
    mov rdx, 56                    ; Taille d'un PHDR
    mov rax, 0                     ; syscall: read
    syscall

    ; Vérifier si le type est PT_NOTE
    mov rax, [phdr_buffer]         ; p_type (premier champ du PHDR)
    cmp rax, 4                     ; PT_NOTE est de type 4
    je pt_note_found               ; Si trouvé, afficher le message de succès

    ; Incrémenter le compteur d'itérations et sauvegarder
    inc rdx
    mov [iter_count], rdx

     ; Afficher le nombre d'itérations après chaque recherche
    mov rdi, no_pt_note_msg        ; Message temporaire pour afficher les itérations
    mov rsi, rdx                   ; Passer le compteur d'itérations comme message
    call print_message

    ; Passer au prochain PHDR
    add rbx, 56                    ; Avancer de la taille d'un PHDR
    mov rdi, [fd]                  ; Descripteur de fichier
    mov rax, 8                     ; syscall: lseek
    mov rsi, rbx                   ; Positionner à la prochaine entrée
    xor rdx, rdx                   ; SEEK_SET
    syscall

    jmp find_pt_note               ; Recommencer la boucle

no_pt_note:
    mov rdi, no_pt_note_msg        ; Message d'erreur
    call print_message
    jmp error_exit

pt_note_found:
    mov rdi, pt_note_found_msg     ; Message de succès
    call print_message

    ; Convertir PT_NOTE en PT_LOAD
    mov dword [buffer + 208], 1     ; Modifier p_type en PT_LOAD (valeur 1)
    mov dword [buffer + 212], 0x5

    ; Positionner le curseur pour écrire le PHDR modifié
    mov rdi, [fd]                  ; Descripteur de fichier
    mov rax, 8                     ; syscall: lseek
    mov rsi, rbx                   ; Offset actuel du PHDR
    xor rdx, rdx                   ; SEEK_SET
    syscall

    ; Écrire le PHDR modifié dans le fichier
    mov rdi, [fd]                  ; Descripteur de fichier
    mov rsi, phdr_buffer           ; Tampon contenant le PHDR modifié
    mov rdx, 56                    ; Taille d'un PHDR
    mov rax, 1                     ; syscall: write
    syscall
    test rax, rax                  ; Vérifier si l'écriture a échoué
    js error_exit                  ; Si oui, afficher un message d'erreur

    ; Afficher le message de succès
    mov rdi, pt_note_modified_msg
    call print_message
    jmp exit_success

print_message:
    ; Charger l'adresse du message dans rsi
    mov rsi, rdi                ; Charger l'adresse du message dans rsi
    call find_length            ; Trouver la longueur du message
    call write_message          ; Écrire le message
    ret

find_length:
    xor rcx, rcx                ; Initialiser le compteur de longueur à 0
find_length_loop:
    mov al, byte [rsi + rcx]    ; Lire un octet du message
    test al, al                 ; Vérifier si c'est le terminator null (0)
    je find_length_done         ; Si oui, terminer
    inc rcx                     ; Sinon, incrémenter la longueur
    jmp find_length_loop
find_length_done:
    mov rdx, rcx                ; Charger la longueur trouvée dans rdx
    ret                         ; Retourner à l'appelant

write_message:
    ; rsi contient l'adresse du message, rdx contient la longueur
    mov rax, 1                  ; syscall: write
    mov rdi, 1                  ; Descripteur pour stdout
    syscall                     ; Appeler write
    ret                         ; Retourner à l'appelant

error_exit:
    mov rax, 60                    ; syscall: exit
    mov rdi, 1                     ; Code de sortie 1
    syscall

exit_success:
    mov rax, 60                    ; syscall: exit
    xor rdi, rdi                   ; Code de sortie 0
    syscall