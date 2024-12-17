# M̵̢̨̗̤̠͔̅͑͋̎̉̀́̏̕Á̴͖̅͆̅͌́̀L̴̡̻͚͙͉͎̭͖̇̾́̀͊̇̈͝D̶̬̹͔̗̲͖̝͆̽͛E̶̤͋̋́̐̿̎̀̾̀V̸̬̥͓̓̒ : PT_NOTE to PT_LOAD Injection in ELF

<p align="center">
  <img src="https://github.com/user-attachments/assets/fb379c8c-fadb-4d42-b796-26fdc65862e0" width="300"/>
</p>

## Projet Maldev : Implémentez à partir de zéro sans compter sur du code externe un infecteur ptnote → ptload ELF

Ce projet a pour objectif de réaliser une injection de code dans un ELF afin d'exécuter un payload tout en maintenant le comportement d'origine du programme. La méthode utilisée repose sur la transformation d'un segment **PT_NOTE** en segment **PT_LOAD**. Cela permet au code injecté de s'exécuter au démarrage du programme.

- **PT_LOAD** : Segment contenant du code ou des données qui seront chargées en mémoire lors de l'exécution.
- **PT_NOTE** : Segment utilisé pour stocker des informations non critiques, comme des métadonnées ou des annotations.

___ 

### <ins> Méthode de l'infection </ins>

1. **Identification du Segment PT_NOTE** :
   - Analyse des program header pour trouver un `p_type = 4` correspondant au type d'un **PT_NOTE**.

2. **Modification des Propriétés du Segment** :
   - Modification du `p_type` de 4 à 1 correspondant au type d'un **PT_LOAD**. 

3. **Injection du Code Personnalisé** :
   - Injection du payload dans l'espace mémoire du **PT_LOAD** nouvellement transformé.

4. **Redirection du Flux d'Exécution** :  
   - Le point d'entrée de l'exécutable est modifié pour exécuter le payload en premier.  
   - Après l'exécution du payload, le contrôle doit être redirigé vers le point d'entrée original pour maintenir le comportement initial du binaire.

### <ins>Etapes de réalisation de l'infection</ins>
1. :heavy_check_mark:  Ouvrir le fichier ELF à injecter. 
2. :heavy_check_mark:  Sauvegarder le point d'entrée original, **e_entry**.  
3. :heavy_check_mark:  Analyser la table des en-têtes de programme pour trouver un segment **PT_NOTE**.  
4. :heavy_check_mark:  Convertir le segment **PT_NOTE** en un segment **PT_LOAD**.  
5. :heavy_check_mark:  Modifier les protections mémoire de ce segment pour autoriser l'exécution d'instructions.  
6. :heavy_check_mark:  Changer l'adresse du point d'entrée vers une zone qui n'entrera pas en conflit avec l'exécution originale du programme.
7. :heavy_check_mark:  Créer et ajouter le payload dans le binaire.  
8. :heavy_check_mark:  Ajuster la taille sur le disque et la taille en mémoire virtuelle pour prendre en compte la taille du code injecté.  
9. :heavy_check_mark:  Pointer le décalage de notre segment converti vers la fin du binaire original, où sera stocké le nouveau code.  
10. :x:  Modifier la fin du code injecté avec des instructions pour sauter vers le point d'entrée original.



---

<br>

## Comportement de l'ELF cible et du programme infectieux Maldev

### <ins>L'ELF cible : *Hello World !*</ins> :smiley:

> L'ELF cible est un programme en C qui affiche `Hello World !` dans le terminal.


### <ins>Programme Infectieux Maldev </ins> :smiling_imp:

> Le payload de Maldev sert à afficher dans la console `INFECTED` avant de rediriger le flux d'exécution vers le comportement de base de l'ELF cible.



---

<br>

# MALDEV : Résultat

L'infection de l'ELF par **Maldev** est *partiellement* réussie : 
- Lors de l'exécution du programme infecté, le payload s'exécute correctement et affiche `INFECTED`, ce qui confirme que l'injection et la modification du point d'entrée fonctionnent.
- Cependant 'exécution ne parvient pas à retourner au comportement original du binaire, empêchant l'affichage du `Hello, World!`.

![Screenshot from 2024-12-17 14-06-25](https://github.com/user-attachments/assets/494637e0-2e45-4713-83e0-d1aa7165584b)

> [!NOTE]
> Je sais que le problème réside dans la redirection vers le code de base après l'exécution du payload, mais malgré plusieurs tentatives, cela reste un point à résoudre pour finaliser l'infection.

<br>


## Problèmes Rencontrés

Ce projet, bien que complexe et jalonné d'obstacles, a été une expérience particulièrement enrichissante sur le plan des connaissances. Certains défis, notables ou plus minimes, m'ont demandé beaucoup de temps, et il est parfois arrivé que des corrections fonctionnent sans que la raison exacte derrière leur résolution ne soit parfaitement claire. Voici les deux problèmes qui m'ont pris le plus de temps à résoudre :

<ins> Boucle Infinie sur la recherche du **PT_NOTE** et modification non prise en compte</ins>
![Screenshot from 2024-12-15 23-19-23](https://github.com/user-attachments/assets/fc0440cc-3e6e-41b3-a4f0-f2db2bd17371)

Sur ce screenshot on peut voir que ma boucle pour rechercher mon PT_NOTE dépassait les 13 itérations alors qu'il n'y avait que 13 en-têtes.
> Il y avait plus de 50 itérations.

Heureusement, dans ce cas, le PT_NOTE a été trouvé à la fin, mais il est arrivé que le programme entre dans une boucle infinie sans jamais le trouver. La cause de ce problème résidait dans une condition d'arrêt mal paramétrée et une valeur incorrecte pour `sh_size`, la taille des segments.

De plus, lors de la modification du PT_NOTE en PT_LOAD, j'ai constaté, en utilisant readelf, que la modification n'avait pas été prise en compte. En réalité, je modifiais la valeur de `p_type`, mais je ne mettais pas à jour le header ELF en écrivant les changements.

<ins> Redirection du flux d'exécution vers le point d'entrée d'origine </ins>

Le principal problème rencontré, qui n'est toujours pas résolu à ce jour, concerne la redéfinition du point d'entrée lors de l'infection du binaire. Celui-ci est modifié pour pointer vers le début du payload afin de l'exécuter en priorité. Cependant, une fois le payload executée, lorsque j'effectue le saut vers l'adresse du point d'entrée d'origine, je ne parviens pas à accéder au début du programme, mais plutôt à des métadonnées, comme illustré dans la capture d'écran.

![Screenshot from 2024-12-17 14-06-25](https://github.com/user-attachments/assets/494637e0-2e45-4713-83e0-d1aa7165584b)

Le problème réside dans le fait que je calcule l'adresse du point d'entrée d'origine en fonction de l'adresse actuelle du programme, mais ce calcul d'adresse relative est erroné, ce qui entraîne un saut vers une section mémoire incorrecte. Heureusement, cette section mémoire se trouve sans doute dans la zone `.text`, qui affiche des caractères et ne provoque pas de `segmentation fault`.

---

<br>

## Perspectives d'amélioration
- Permettre de spécifier le nom du binaire en argument.
- Créer deux versions de l'infection, adaptées aux deux architectures ELF (32 bits et 64 bits).
- Ajouter une vérification pour déterminer si le binaire a déjà été infecté.
- Explorer la possibilité de propagation de l'infection, éventuellement en développant un programme récursif.
- Corriger la mauvaise redirection du flux pour améliorer le comportement du programme.

---

## Setup et Reproduction


---

<br>

<br>

<u>Sources : </u>
- https://tmpout.sh/1/2.html
- https://refspecs.linuxbase.org/elf/gabi4+/ch5.pheader.html
- https://x64.syscall.sh/
