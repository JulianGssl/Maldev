# Maldev
Implement from scratch without relying on external code an ptnote→ptload ELF infector

1. Réaliser un binaire en apparence inoffensif qui exécute des commandes linux de base
2. Infecter le binaire pour que les commandes linux de base soit réalisé en même temps que l'infection

idée : 
- Faire le parseur ELF
- Faire l'injection dans le pt_note
- Vérifier quel est la classe ELF
- Faire 2 versions de l'infection pour les deux classes ELF (32 - 64)
