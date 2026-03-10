# AMAP App

Application mobile Flutter pour gérer les paniers d'une AMAP.

## Fonctionnalités

- **Photo + OCR** : capturez la liste de votre panier, les produits sont extraits automatiquement
- **Saisie manuelle** : ajoutez ou corrigez les produits et quantités
- **Comparaison prix** : comparez le coût bio vs conventionnel pour chaque livraison
- **Catalogue produits** : recherche Open Food Facts + saisie manuelle
- **Analytics** : graphiques hebdomadaires/mensuels, économies réalisées, distribution par catégorie
- **Multi-utilisateur** : chaque membre voit ses propres livraisons (RLS Supabase)

## Stack technique

| Couche | Technologie |
|--------|------------|
| Frontend | Flutter 3.x (Dart) |
| Backend | Supabase (PostgreSQL + Auth + Storage) |
| State | Riverpod 2.x avec code generation |
| Navigation | GoRouter 14.x |
| OCR | Google ML Kit (on-device) |
| Charts | fl_chart |
| HTTP | Dio |
| Modèles | Freezed + json_serializable |
| Données prix | Open Food Facts API + Open Prices API |

## Configuration

### 1. Supabase

1. Créez un projet sur [supabase.com](https://supabase.com)
2. Exécutez le schéma SQL : `supabase/schema.sql`
3. Créez le bucket Storage `delivery-photos` (privé)
4. Décommentez les policies Storage dans `schema.sql` et exécutez-les

### 2. Variables d'environnement

Ne jamais committer de clés dans git. Utilisez `--dart-define` :

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

Ou créez un fichier `.env` (ajouté au `.gitignore`) et utilisez `flutter_dotenv`.

### 3. Installation

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

### 4. Génération de code

Les fichiers `*.freezed.dart` et `*.g.dart` sont générés automatiquement :

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Structure du projet

```
lib/
├── core/           # Config, router, theme, widgets communs
├── features/
│   ├── auth/       # Login, register, profile
│   ├── delivery/   # Camera, OCR, panier, liste livraisons
│   ├── products/   # Catalogue, recherche OFF, détail
│   ├── price_comparison/  # Tableau bio vs conv, historique
│   └── analytics/  # Dashboard graphiques
└── services/       # Connectivity
```

## Tests

```bash
flutter test                    # Unit + widget tests
flutter test integration_test/  # Integration tests
```

## Build production

```bash
# Android APK
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...

# iOS IPA
flutter build ipa \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```
