# SlimeBomb - Drag & Throw

Un jeu mobile addictif de type "drag & throw" developpe avec Godot 4.6.

## Concept

Des balles tombent du haut de l'ecran :
- Balles CYAN -> Jeter vers la DROITE
- Balles MAGENTA -> Jeter vers la GAUCHE
- Balles YELLOW -> Jeter gauche OU droite
- BOMBES -> NE PAS TOUCHER (Game Over)

## Quick Start

### 1. Ouvrir le projet dans Godot

```bash
# Ouvrir Godot 4.6
# File > Import > Selectionner ce dossier
# Ou double-cliquer sur project.godot
```

### 2. GlobalSettings (Autoload)

`GlobalSettings` est deja configure dans `project.godot`.

Si tu ne le vois pas dans `Project > Project Settings > Autoload`, ajoute:
- Path: `res://scripts/GlobalSettings.gd`
- Node Name: `GlobalSettings`

### 3. Lancer le jeu

Appuyer sur F5 ou cliquer sur Play

### 4. Tester sur PC

- Utiliser la souris pour simuler le tactile
- Cliquer, drag, relacher pour jeter
- Emulate Touch from Mouse est active

## Structure du projet

```
SlimeBomb/
├── scenes/
│   ├── minigames/
│   │   └── DragThrowGame.tscn       # Scene principale du jeu
│   └── objects/
│       └── BallDragThrow.tscn       # Prefab de la balle
├── scripts/
│   ├── minigames/
│   │   └── DragThrowGame.gd         # Logique principale
│   ├── objects/
│   │   └── BallDragAndThrow.gd      # Script de la balle
│   └── GlobalSettings.gd            # Settings globaux (Singleton)
├── assets/
└── project.godot
```

## Fonctionnalites actuelles

Core Gameplay
- Drag & Throw tactile optimise
- Spawn dynamique des balles
- 4 types de balles (Cyan, Magenta, Yellow, Bombe)
- Detection de collision precise

Progression
- Systeme de score avec combo multiplier
- High score sauvegarde
- Difficulte progressive (gravite + spawn rate)
- Systeme de vies (3 vies)

Feedback Visuel
- Screen shake sur impact
- Flash d'ecran (succes/erreur)
- Particules de succes
- Popup de points + bonus Perfect

UI
- Score en temps reel
- Affichage du combo
- Vies restantes
- Ecran Game Over avec retry + stats

## Prochaines etapes (Voir NEXT_STEPS.md)

Phase 1 - Polish
- Ajouter des vrais sprites
- Integrer sons et musique
- Ameliorer l'UI/UX

Phase 2 - Monetisation
- Integrer AdMob
- Systeme de monnaie virtuelle
- Shop de skins
- Achats in-app

Phase 3 - Retention
- Missions quotidiennes
- Systeme de niveaux et XP
- Achievements Google Play
- Leaderboard global
- Power-ups

Phase 4 - Launch
- Optimisation performance mobile
- Export Android
- Screenshots + trailer
- Publication Play Store

## Assets necessaires

Sprites
- `ball_cyan_glow.svg`
- `ball_magenta_glow.svg`
- `ball_yellow_glow.svg`
- `bomb_glow.svg`

Sons
- grab / throw
- correct / wrong
- bomb_explosion
- combo_increase
- background_music
