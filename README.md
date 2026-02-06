# 🎮 SlimeBomb - Swipe Rush

Un jeu mobile addictif de type "swipe ball" développé avec Godot 4.6.

## 🎯 Concept

Des balles tombent du haut de l'écran:
- 🟢 **Balles VERTES** → Swipe vers la DROITE
- 🔴 **Balles ROUGES** → Swipe vers la GAUCHE
- 💣 **BOMBES NOIRES** → NE PAS TOUCHER (Game Over instantané!)

## 🚀 Quick Start

### 1. Ouvrir le projet dans Godot

```bash
# Ouvrir Godot 4.6
# File > Import > Sélectionner ce dossier
# Ou double-cliquer sur project.godot
```

### 2. Configurer GlobalSettings (Important!)

1. Aller dans **Project > Project Settings > Autoload**
2. Cliquer sur **Add**
3. Path: `res://scripts/GlobalSettings.gd`
4. Node Name: `GlobalSettings`
5. Cliquer **Add**

### 3. Lancer le jeu

Appuyer sur **F5** ou cliquer sur le bouton **Play** ▶️

### 4. Tester sur PC

- Utiliser la **souris** pour simuler le tactile
- Cliquer et glisser pour swiper
- Les inputs tactiles sont automatiquement simulés

## 📁 Structure du projet

```
SlimeBomb/
├── scenes/
│   ├── minigames/
│   │   └── SwipeGame.tscn       # Scène principale du jeu
│   └── objects/
│       └── Ball.tscn            # Prefab de la balle
├── scripts/
│   ├── minigames/
│   │   ├── SwipeGame.gd         # Logique principale
│   │   └── SwipeInputManager.gd # Gestion du tactile
│   ├── objects/
│   │   └── Ball.gd              # Script de la balle
│   └── GlobalSettings.gd        # Settings globaux (Singleton)
├── assets/
│   ├── sfx/                     # Sons (à ajouter)
│   └── particles/               # Effets (à ajouter)
├── icon.svg                     # Icône du jeu
├── project.godot                # Configuration Godot
├── README.md                    # Ce fichier
└── NEXT_STEPS.md                # Guide complet monétisation
```

## 🎮 Fonctionnalités actuelles

✅ **Core Gameplay**
- Système de swipe tactile optimisé
- Spawn dynamique des balles
- 3 types de balles (Vert, Rouge, Bombe)
- Détection de collision précise

✅ **Progression**
- Système de score avec combo multiplier
- High score sauvegardé
- Difficulté progressive (gravité + spawn rate)
- Système de vies (3 vies)

✅ **Feedback Visuel**
- Screen shake sur impact
- Flash d'écran (succès/erreur)
- Particules de succès
- Popup de points

✅ **UI**
- Score en temps réel
- Affichage du combo
- Vies restantes
- Écran Game Over avec retry

## 🔧 Prochaines étapes (Voir NEXT_STEPS.md)

### PHASE 1 - Polish (1 semaine)
- [ ] Ajouter des vrais sprites (remplacer les cercles)
- [ ] Intégrer sons et musique
- [ ] Créer un menu principal
- [ ] Améliorer l'UI/UX

### PHASE 2 - Monétisation (1 semaine)
- [ ] Intégrer AdMob (interstitiel + rewarded)
- [ ] Système de monnaie virtuelle (coins)
- [ ] Shop de skins
- [ ] Achats in-app (remove ads, skins)

### PHASE 3 - Rétention (1 semaine)
- [ ] Missions quotidiennes
- [ ] Système de niveaux et XP
- [ ] Achievements Google Play
- [ ] Leaderboard global
- [ ] Power-ups (slow-mo, shield, etc.)

### PHASE 4 - Launch (1 semaine)
- [ ] Optimisation performance mobile
- [ ] Export Android (APK/AAB)
- [ ] Screenshots + trailer
- [ ] Publication Play Store

## 📱 Export Android

### Prérequis
1. Android SDK installé (via Android Studio)
2. Keystore créé pour signature

### Build
```bash
# Debug
Project > Export > Android > Export Project

# Release (Play Store)
Project > Export > Android > Export Project (Release)
```

### Configuration export.cfg
Voir les instructions dans NEXT_STEPS.md section "Export Android"

## 🎨 Assets nécessaires

### Sprites (64x64 pixels)
- `ball_green.png` - Balle verte brillante
- `ball_red.png` - Balle rouge brillante
- `bomb.png` - Bombe avec mèche
- `background.png` - Fond dégradé

### Sons (Format OGG)
- `swipe_correct.wav` - Son de succès
- `swipe_wrong.wav` - Son d'erreur
- `bomb_explosion.wav` - Explosion
- `combo_increase.wav` - Combo
- `background_music.ogg` - Musique de fond

### Où trouver:
- **Sprites:** [itch.io](https://itch.io/game-assets/free), [Kenney.nl](https://kenney.nl/)
- **Sons:** [Freesound.org](https://freesound.org/), [Zapsplat](https://www.zapsplat.com/)
- **Musique:** [Incompetech](https://incompetech.com/)

## 🐛 Debugging

### Le jeu ne démarre pas
- Vérifier que GlobalSettings est bien dans les Autoload
- Vérifier que ball_scene est assigné dans SwipeGame.tscn

### Les swipes ne fonctionnent pas
- Vérifier que SwipeInputManager est dans la scène
- Activer "Emulate Touch from Mouse" dans les settings

### Performances lentes
- Réduire particle_quality dans GlobalSettings
- Limiter le nombre de balles simultanées (max 10)

## 📊 Métriques de succès

**Objectifs Day 30 après launch:**
- 10,000+ downloads
- Retention D1: 40%+
- Retention D7: 20%+
- Session length: 5+ minutes
- Revenue: $500+/month

## 🤝 Contribution

Pour améliorer le jeu:
1. Fork le projet
2. Créer une branche (`feature/nouvelle-fonctionnalite`)
3. Commit les changements
4. Push et créer une Pull Request

## 📄 License

Ce projet est sous license MIT. Libre d'utilisation et modification.

## 🎯 Support

Pour toute question ou problème:
- Ouvrir une issue sur GitHub
- Consulter la [documentation Godot](https://docs.godotengine.org/)
- Rejoindre le [Discord Godot](https://discord.gg/godotengine)

---

**Développé avec ❤️ en Godot 4.6**

*Prêt à swiper jusqu'à l'addiction?* 🔥
