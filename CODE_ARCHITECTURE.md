# 🏗️ Architecture du Code - SlimeBomb

## 📊 Vue d'ensemble

```
┌─────────────────────────────────────────────────────────┐
│                    SwipeGame.tscn                       │
│  (Scène principale - Node2D Root)                      │
│                                                         │
│  ┌────────────────────────────────────────────────┐   │
│  │  SwipeGame.gd                                   │   │
│  │  • Gère le game loop                            │   │
│  │  • Spawning des balles                          │   │
│  │  • Scoring & combo                              │   │
│  │  • Difficulté progressive                       │   │
│  │  • Game Over logic                              │   │
│  └────────────────────────────────────────────────┘   │
│                                                         │
│  ┌────────────────────────────────────────────────┐   │
│  │  SwipeInputManager.gd                           │   │
│  │  • Détection des swipes tactiles                │   │
│  │  • Support souris (pour testing)                │   │
│  │  • Calcul direction/vitesse du swipe            │   │
│  │  • Raycast pour collision swipe-balle           │   │
│  └────────────────────────────────────────────────┘   │
│                                                         │
│  ┌────────────────────────────────────────────────┐   │
│  │  Ball instances (RigidBody2D)                   │   │
│  │  • Ball.gd - Logique de chaque balle            │   │
│  │  • Physique (gravité, forces)                   │   │
│  │  • Feedback visuel (particules, flash)          │   │
│  │  • Signaux vers SwipeGame                       │   │
│  └────────────────────────────────────────────────┘   │
│                                                         │
│  ┌────────────────────────────────────────────────┐   │
│  │  UI Layer (CanvasLayer)                         │   │
│  │  • Labels (Score, Combo, Lives)                 │   │
│  │  • Popups dynamiques                            │   │
│  │  • Écran Game Over                              │   │
│  └────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

         ↕ Communication via Signals

┌─────────────────────────────────────────────────────────┐
│              GlobalSettings (Autoload)                  │
│  • Singleton accessible partout                        │
│  • Save/Load des données                               │
│  • Settings globaux (volume, vibration, etc.)          │
│  • Progression joueur (level, XP, coins)               │
└─────────────────────────────────────────────────────────┘
```

---

## 🎯 Flux de jeu (Game Loop)

### 1. Initialisation (`_ready()`)

```gdscript
SwipeGame._ready():
  ↓
  Load high score
  ↓
  Setup spawn timer (1.5s initial)
  ↓
  Setup difficulty timer (10s interval)
  ↓
  Initialize UI
  ↓
  Start game loop
```

### 2. Spawn Loop

```gdscript
Every spawn_timer.timeout:
  ↓
  _spawn_ball()
    ↓
    Instantiate Ball from scene
    ↓
    Random position (top of screen)
    ↓
    Random type (GREEN | RED | BOMB)
      • Bomb: 15% chance
      • Green: ~42.5%
      • Red: ~42.5%
    ↓
    Apply gravity scale (increases with time)
    ↓
    Connect signals
    ↓
    Add to scene tree
```

### 3. Input Processing

```gdscript
User touch/swipe:
  ↓
  SwipeInputManager._input(event)
    ↓
    Track touch start/move/end
    ↓
    Build touch trail (last 10 positions)
    ↓
  On touch end:
    ↓
    Calculate swipe vector & velocity
    ↓
    Check minimum distance (50px)
    ↓
    Emit swipe_detected signal
    ↓
    _check_ball_hit()
      ↓
      PhysicsPointQuery on trail positions
      ↓
      If Ball found:
        ↓
        ball.handle_swipe(direction)
```

### 4. Ball Logic

```gdscript
Ball.handle_swipe(direction):
  ↓
  Is BOMB?
    Yes → _explode() → bomb_touched signal → GAME OVER
    No ↓
  Check swipe direction:
    • GREEN + RIGHT swipe = ✅ Correct
    • RED + LEFT swipe = ✅ Correct
    • Other combinations = ❌ Wrong
    ↓
  If correct:
    ↓
    Apply impulse (swipe force)
    ↓
    Spawn success particles
    ↓
    Calculate points (base + height bonus)
    ↓
    Emit ball_swiped_correctly(points)
    ↓
    Destroy after 2s
  ↓
  If wrong:
    ↓
    Flash red
    ↓
    Small impulse (feedback)
    ↓
    Emit ball_swiped_wrong
```

### 5. Scoring System

```gdscript
On ball_swiped_correctly(points):
  ↓
  Increment combo
  ↓
  Calculate multiplier: 1.0 + (combo * 0.1)
  ↓
  total_points = points * multiplier
  ↓
  score += total_points
  ↓
  Update UI
  ↓
  Show score popup
  ↓
  Play success sound
```

```gdscript
On ball_swiped_wrong OR ball reaches KillZone:
  ↓
  Reset combo to 0
  ↓
  lives -= 1
  ↓
  Screen shake
  ↓
  Flash red
  ↓
  Update UI
  ↓
  If lives <= 0:
    ↓
    _game_over()
```

### 6. Difficulté Progressive

```gdscript
Every difficulty_timer.timeout (10s):
  ↓
  Decrease spawn_rate by 0.05s
    • Min: 0.4s (max difficulty)
  ↓
  Increase bomb_spawn_chance by 2%
    • Max: 35%
  ↓
  Gravity scale increases with time:
    • gravity_scale = 1.0 + (time_elapsed / 60.0)
    • After 60s: gravity_scale = 2.0
```

---

## 📡 Système de Signaux

### Ball → SwipeGame

```gdscript
signal ball_swiped_correctly(points: int)
  • Émis quand bonne direction
  • Points = 10-30 selon hauteur

signal ball_swiped_wrong()
  • Émis quand mauvaise direction
  • Ou quand balle touche KillZone sans swipe

signal bomb_touched()
  • Émis quand bombe touchée
  • Game Over instantané
```

### SwipeInputManager → (Global)

```gdscript
signal swipe_detected(position: Vector2, direction: Vector2, velocity: float)
  • Position: Point de départ du swipe
  • Direction: Vecteur normalisé
  • Velocity: Pixels/seconde
  • (Actuellement non utilisé en global, mais utile pour extensions)
```

---

## 💾 Système de Sauvegarde

### Architecture

```gdscript
GlobalSettings (Autoload)
  ↓
  save_game() → FileAccess.open("user://savegame.save")
    ↓
    Sérialiser toutes les variables en JSON
    ↓
    Écrire dans le fichier
    ↓
  Done

  load_game() → FileAccess.open("user://savegame.save")
    ↓
    Lire le JSON
    ↓
    Parser et restaurer les variables
    ↓
  Done
```

### Données sauvegardées

**Settings:**
- Volume (master, music, sfx)
- Préférences (vibration, particles, etc.)

**Progression:**
- Level & XP
- Coins
- Skins débloqués
- Power-ups possédés

**Stats:**
- Total games played
- Total score
- Max combo
- Accuracy
- Playtime

**Monétisation:**
- Ads disabled (achat)
- Premium status
- Missions completed

---

## 🎨 Système Visuel (Feedback)

### Screen Shake

```gdscript
Camera2D offset randomization:
  ↓
  shake_amount (intensity)
  ↓
  Lerp vers 0 avec shake_decay
  ↓
  Random offset chaque frame
  ↓
  Smooth stop
```

### Particules

**Success Particles (GPUParticles2D):**
- Emission: Burst de 20 particules
- Direction: Vers le haut
- Couleur: Jaune/doré
- Lifetime: 0.8s

**Explosion Particles:**
- Emission: Burst de 50 particules
- Direction: Omnidirectionnelle
- Couleur: Orange/rouge
- Lifetime: 1.0s

### Flash Effect

```gdscript
ColorRect overlay:
  ↓
  Tween modulate.a from 1.0 → 0.0
  ↓
  Duration: 0.3s
  ↓
  Auto-destroy
```

---

## 🔧 Points d'Extension

### 1. Ajouter un nouveau type de balle

```gdscript
# Dans Ball.gd
enum BallType {
    GREEN,
    RED,
    BOMB,
    BLUE  # ← Nouveau type
}

# Dans SwipeGame.gd _spawn_ball()
# Ajouter la logique de spawn pour BLUE

# Dans Ball.gd _setup_visuals()
# Ajouter le visuel pour BLUE

# Dans Ball.gd handle_swipe()
# Ajouter la règle (ex: BLUE = swipe vers le BAS)
```

### 2. Ajouter un Power-up

```gdscript
# Créer scripts/powerups/PowerupBase.gd
class_name Powerup
extends Node

signal powerup_activated
signal powerup_expired

var duration: float
var is_active: bool = false

func activate():
    is_active = true
    powerup_activated.emit()
    # Logic...

func deactivate():
    is_active = false
    powerup_expired.emit()
```

### 3. Ajouter une nouvelle scène (Menu)

```gdscript
# Créer scenes/ui/MainMenu.tscn
# Créer scripts/ui/MainMenu.gd

# Dans MainMenu.gd
func _on_play_button_pressed():
    get_tree().change_scene_to_file("res://scenes/minigames/SwipeGame.tscn")

func _on_settings_button_pressed():
    # Ouvrir settings popup
```

### 4. Intégrer AdMob

```gdscript
# Créer scripts/managers/AdManager.gd (Autoload)

var admob: AdMob

func _ready():
    if Engine.has_singleton("AdMob"):
        admob = Engine.get_singleton("AdMob")
        admob.initialize()

# Dans SwipeGame._game_over()
func _game_over():
    # ...
    AdManager.show_interstitial()
```

---

## 🧪 Points de Test

### Testing Checklist

**Gameplay:**
- [ ] Balles spawent correctement
- [ ] Swipe détecté précisément
- [ ] Bonne balle + bon swipe = points
- [ ] Mauvais swipe = perte de vie
- [ ] Bombe touchée = Game Over immédiat
- [ ] Combo augmente/reset correctement

**UI:**
- [ ] Score s'affiche
- [ ] Combo visible uniquement si > 1
- [ ] Lives décrémentent
- [ ] Game Over screen apparaît
- [ ] Retry fonctionne

**Progression:**
- [ ] Difficulté augmente avec le temps
- [ ] High score sauvegardé
- [ ] Balles tombent plus vite après 30s

**Performance:**
- [ ] 60 FPS constant
- [ ] Pas de lag au spawn
- [ ] Pas de memory leak (balles détruites)

---

## 📊 Métriques & Debug

### Afficher les FPS

```gdscript
# Dans SwipeGame.gd _ready()
if GlobalSettings.show_fps:
    var fps_label = Label.new()
    fps_label.name = "FPS"
    $CanvasLayer.add_child(fps_label)

# Dans _process()
if has_node("CanvasLayer/FPS"):
    $CanvasLayer/FPS.text = "FPS: " + str(Engine.get_frames_per_second())
```

### Logging des événements

```gdscript
# Activer dans SwipeGame.gd
const DEBUG = true

func _spawn_ball():
    if DEBUG: print("Spawning ball of type: ", ball.ball_type)

func _on_ball_swiped_correctly(points):
    if DEBUG: print("Correct swipe! Points: ", points, " Combo: ", combo)
```

---

## 🚀 Optimisations Futures

### 1. Object Pooling

```gdscript
# Au lieu de instantiate() à chaque fois
var ball_pool: Array[Ball] = []
var pool_size = 20

func _get_ball_from_pool() -> Ball:
    for ball in ball_pool:
        if not ball.visible:
            ball.visible = true
            return ball
    # Si pool vide, créer nouvelle balle
    var new_ball = ball_scene.instantiate()
    ball_pool.append(new_ball)
    return new_ball
```

### 2. Batch Rendering

```gdscript
# Utiliser MultiMesh pour plusieurs balles identiques
var multimesh = MultiMesh.new()
multimesh.mesh = SphereMesh.new()
multimesh.instance_count = 100
```

### 3. Async Loading

```gdscript
# Pour les assets lourds
func _load_texture_async(path: String):
    ResourceLoader.load_threaded_request(path)
    # Later...
    var texture = ResourceLoader.load_threaded_get(path)
```

---

## 📝 Convention de Code

### Nommage

```gdscript
# Variables
var player_score: int          # snake_case
var is_game_over: bool         # is_ prefix pour bool
var max_combo: int             # descriptif

# Fonctions
func calculate_points():       # snake_case, verbe
func _on_button_pressed():     # callbacks: _on_
func _internal_method():       # privé: _ prefix

# Constantes
const MAX_LIVES = 3            # UPPER_CASE
const SPAWN_RATE = 1.5

# Classes
class_name Ball                # PascalCase

# Signaux
signal ball_swiped_correctly   # snake_case, past tense
```

### Organisation

```gdscript
# Ordre dans un script:
1. class_name
2. extends
3. signals
4. enums
5. @export variables
6. public variables
7. private variables
8. @onready variables
9. _init()
10. _ready()
11. _process()
12. public functions
13. private functions (_)
14. signal callbacks (_on_)
```

---

## 🎯 Résumé Architecture

**Principes:**
- ✅ Séparation des responsabilités (MVC-like)
- ✅ Communication via signaux (loose coupling)
- ✅ Singleton pour state global (GlobalSettings)
- ✅ Scenes réutilisables (Ball.tscn)
- ✅ Feedback visuel/audio pour chaque action

**Points forts:**
- Code modulaire et extensible
- Facile d'ajouter nouveaux types de balles
- Système de progression déjà prévu
- Performance optimisée mobile

**À améliorer:**
- Ajouter object pooling (si lag)
- State machine pour game states
- Séparation UI dans des scenes propres
- Configuration via fichiers JSON

---

💡 **Cette architecture est conçue pour être facilement extensible. Chaque nouveau feature (skins, power-ups, missions) peut s'intégrer sans refactoring majeur !**
