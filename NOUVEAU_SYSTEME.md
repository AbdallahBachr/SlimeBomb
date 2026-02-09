# Nouveau Systeme - Drag & Throw

## Gameplay

Avant: Swipe rapide (difficile)
Maintenant: Drag & Throw (intuitif et satisfaisant)

Comment jouer:
1. Cliquer sur une balle qui tombe
2. Tenir et drag dans une direction
3. Relacher pour jeter

Regles:
- CYAN -> Jeter a DROITE
- MAGENTA -> Jeter a GAUCHE
- YELLOW -> Jeter gauche ou droite
- BOMBE -> Ne pas toucher (Game Over)

## Ce qui est en place

Architecture principale:
- `scripts/objects/BallDragAndThrow.gd` : grab / drag / throw
- `scenes/objects/BallDragThrow.tscn` : scene de balle input_pickable
- `scripts/minigames/DragThrowGame.gd` : game manager, scoring, difficulty
- `scenes/minigames/DragThrowGame.tscn` : scene principale

Systeme de scoring:
- Base: 10 points
- Combo: +15% par balle consecutive
- Bonus Perfect: +10 ou +20 si throw rapide et correct

Vies et erreurs:
- 3 vies au depart
- Mauvaise direction = -1 vie
- Balle ratee (tombe ou sort ecran) = -1 vie
- Bombe touchee = Game Over

Progression:
- Spawn rate accelere par paliers
- Gravite augmente doucement
- Patterns late-game (inversion, burst)

## A verifier

- Input tactile OK (touch + drag + release)
- Wrong throw compte comme miss et detruit la balle
- Out of bounds nettoie les balles perdues
