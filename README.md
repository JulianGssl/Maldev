# M̵̢̨̗̤̠͔̅͑͋̎̉̀́̏̕Á̴͖̅͆̅͌́̀L̴̡̻͚͙͉͎̭͖̇̾́̀͊̇̈͝D̶̬̹͔̗̲͖̝͆̽͛E̶̤͋̋́̐̿̎̀̾̀V̸̬̥͓̓̒ : PT_NOTE to PT_LOAD Injection in ELF


<p align="center">
  <img src="https://github.com/user-attachments/assets/fb379c8c-fadb-4d42-b796-26fdc65862e0" width="300"/>
</p>




## Projet Maldev : Implémentez à partir de zéro sans compter sur du code externe un infecteur ptnote → ptload ELF

La première étape consiste à concevoir un **programme binaire initial, inoffensif, qui se limite à exécuter des commandes Linux simples** et courantes. Ensuite, un **second programme**, écrit en langage assembleur, sera **conçu pour infecter ce binaire initial**. Cet infecteur ajoutera un comportement malveillant au programme, tout en préservant son comportement légitime d'origine.

### Comportement du binaire inoffensif et du programme infecteur

Le binaire initial est un simple programme en C qui affiche `Hello World !` dans le terminal.
Le programme infecteur lui ouvrira un nouveau terminal pour y exécuter la commande `cat /etc/passwd` comme POC de l'infection.


### Etapes de réalisation de l'infection
1. [x] 1. Ouvrir le fichier ELF à injecter. 
2. [x] 2. Sauvegarder le point d'entrée original, **e_entry**.  
3. [x] 3. Analyser la table des en-têtes de programme pour trouver un segment **PT_NOTE**.  
4. [ ] 4. Convertir le segment **PT_NOTE** en un segment **PT_LOAD**.  
5. [ ] 5. Modifier les protections mémoire de ce segment pour autoriser l'exécution d'instructions.  
6. [ ] 6. Changer l'adresse du point d'entrée vers une zone qui n'entrera pas en conflit avec l'exécution originale du programme.  
7. [ ] 7. Ajuster la taille sur le disque et la taille en mémoire virtuelle pour prendre en compte la taille du code injecté.  
8. [ ] 8. Pointer le décalage de notre segment converti vers la fin du binaire original, où sera stocké le nouveau code.  
9. [ ] 9. Modifier la fin du code injecté avec des instructions pour sauter vers le point d'entrée original.  
10. [ ] 10. Ajouter notre code injecté à la fin du fichier.  

Idées : 
- Pouvoir donner le nom du binaire en argument 
- Faire 2 versions de l'infection pour les deux classes ELF (32 - 64)
- Vérifier si le binaire est déjà infecté
- Propagation de l'infection ? Programme récursif ?

<br>

___

<br>

<u>Sources : </u>
- https://tmpout.sh/1/2.html
- https://refspecs.linuxbase.org/elf/gabi4+/ch5.pheader.html
- https://x64.syscall.sh/
