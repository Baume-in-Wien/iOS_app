# Bäume in Wien 🌳

A modern, open-source Android application for exploring Vienna's urban tree cadastre using public city data.

## Overview

**Bäume in Wien** is a civic-tech, nature-focused application that allows users to explore, discover, and learn about the trees in Vienna's public spaces. It uses Baumkataster data from the City of Vienna. Built with modern Android development practices and Material You design principles, the app provides an accessible and privacy-friendly way to interact with Vienna's open government data.

## Features

### ✅ Implemented

- **Offline-First Architecture**: All data cached locally for offline access
- **Material 3 Design**: Modern UI with dynamic theming (Material You)
- **Three Main Screens**:
  - 🗺️ **Map**: Interactive map showing tree locations (MapLibre integration ready)
  - ⭐ **Favorites**: Save and manage your favorite trees
  - ℹ️ **Info**: App information and data attribution
- **Tree Details**: View comprehensive information about each tree
  - Species (German and scientific names)
  - Estimated age and plant year
  - Height and trunk circumference
  - District and location
  - Coordinates
- **Favorites Management**: Mark trees as favorites for quick access
- **Data Attribution**: Proper credit to Stadt Wien open data

### 🚧 To Be Implemented

- Full MapLibre map integration with markers
- Marker clustering for better performance
- Filter functionality (species, height, district)
- Location-based features (distance filtering, nearby trees)
- Search functionality
- Private notes for trees

## Tech Stack

### Core Technologies

- **Language**: Kotlin
- **UI Framework**: Jetpack Compose
- **Design System**: Material 3 (Material You)
- **Architecture**: MVVM + Repository Pattern
- **Minimum SDK**: Android 8.0 (API 26)
- **Target SDK**: Android 14+ (API 36)

### Libraries & Dependencies

#### UI & Navigation
- Jetpack Compose (BOM 2024.12.01)
- Navigation Compose 2.8.5
- Material 3 with dynamic theming
- Lifecycle ViewModel Compose 2.8.7

#### Networking
- Retrofit 2.11.0 (HTTP client)
- Moshi 1.15.1 (JSON parsing)
- OkHttp (included with Retrofit)

#### Local Storage
- Room 2.6.1 (SQLite database)
- DataStore Preferences 1.1.1 (settings)

#### Maps
- MapLibre 11.5.1 (OpenStreetMap rendering)

#### Async & Concurrency
- Kotlin Coroutines 1.9.0
- Kotlin Flow (reactive streams)

#### Location (Optional)
- Play Services Location 21.3.0

## Architecture

### Layers

```
┌─────────────────────────────────────┐
│         UI Layer (Compose)          │
│  - Screens, ViewModels, UI State    │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│       Repository Layer (SSOT)        │
│  - Offline-first data strategy      │
│  - Coordinates network & cache      │
└─────────────────────────────────────┘
        ↓                      ↓
┌───────────────┐     ┌───────────────┐
│  Remote (API) │     │ Local (Room)  │
│  - Retrofit   │     │  - Database   │
│  - WFS/GeoJSON│     │  - DAOs       │
└───────────────┘     └───────────────┘
```

### Key Patterns

- **MVVM**: Separation of concerns with ViewModels managing UI state
- **Repository Pattern**: Single source of truth for data access
- **Offline-First**: Local database is primary data source
- **Reactive UI**: Flow/StateFlow for observing data changes
- **Dependency Injection**: Manual DI via Application class

## Data Source

All tree data comes from the **Vienna Open Government Data (OGD)** portal:

- **Source**: Stadt Wien – data.wien.gv.at
- **Dataset**: Baumkataster (Tree Cadastre)
- **License**: Creative Commons Attribution 4.0 International (CC BY 4.0)
- **API Type**: WFS (Web Feature Service)
- **Format**: GeoJSON
- **Coordinate System**: EPSG:4326 (WGS 84)

### API Endpoint

```
https://data.wien.gv.at/daten/geo
  ?service=WFS
  &version=2.0.0
  &request=GetFeature
  &typeNames=ogdwien:BAUMKATASTEROGD
  &outputFormat=application/json
  &srsName=EPSG:4326
```

## Project Structure

```
app/src/main/java/com/example/baumkatastar/
│
├── data/
│   ├── domain/              # Domain models
│   │   └── Tree.kt
│   ├── local/               # Room database
│   │   ├── TreeDao.kt
│   │   ├── TreeDatabase.kt
│   │   └── TreeEntity.kt
│   ├── remote/              # Network layer
│   │   ├── dto/             # Data transfer objects
│   │   │   ├── GeoJsonResponse.kt
│   │   │   └── DtoMapper.kt
│   │   ├── BaumkatasterApi.kt
│   │   └── RetrofitInstance.kt
│   └── repository/          # Repository pattern
│       ├── Result.kt
│       └── TreeRepository.kt
│
├── ui/
│   ├── navigation/          # Navigation setup
│   │   ├── Screen.kt
│   │   └── BaumkatastarNavGraph.kt
│   ├── screens/
│   │   ├── map/            # Map screen
│   │   │   ├── MapScreen.kt
│   │   │   ├── MapViewModel.kt
│   │   │   └── components/
│   │   │       └── TreeDetailBottomSheet.kt
│   │   ├── favorites/      # Favorites screen
│   │   │   ├── FavoritesScreen.kt
│   │   │   └── FavoritesViewModel.kt
│   │   └── info/           # Info screen
│   │       └── InfoScreen.kt
│   ├── theme/              # Material 3 theming
│   ├── BaumkatastarApp.kt  # Main app composable
│   └── ViewModelFactory.kt
│
├── BaumkatastarApplication.kt  # Application class
└── MainActivity.kt             # Entry point
```

## Privacy & Ethics

### Privacy-First Design

- ❌ No user accounts or login
- ❌ No analytics or tracking
- ❌ No advertisements
- ❌ No custom backend
- ❌ No cloud storage
- ✅ All data stored locally only
- ✅ Favorites and notes stay on device
- ✅ Optional location permission
- ✅ Transparent data sources

### Permissions

- **INTERNET**: Required to fetch public tree data
- **ACCESS_NETWORK_STATE**: Check network availability
- **ACCESS_FINE_LOCATION**: Optional, for distance-based features
- **ACCESS_COARSE_LOCATION**: Optional, for distance-based features

## Building & Running

### Prerequisites

- Android Studio Ladybug or later
- JDK 11 or later
- Android SDK 36
- Gradle 8.13+

### Build Steps

1. **Clone the repository** (when available)
   ```bash
   git clone <repository-url>
   cd Baumkatastar
   ```

2. **Open in Android Studio**
   - File → Open → Select project folder

3. **Sync Gradle**
   - Wait for Gradle sync to complete
   - All dependencies will be downloaded automatically

4. **Run on device or emulator**
   - Click Run (Shift+F10)
   - Select target device

### Gradle Tasks

```bash
# Build debug APK
./gradlew assembleDebug

# Run tests
./gradlew test

# Clean build
./gradlew clean build
```

## Development Roadmap

### Phase 1: Core Functionality ✅ (Current)
- [x] Project setup and dependencies
- [x] Data layer (API, DTOs, Repository)
- [x] Room database for offline storage
- [x] Basic navigation structure
- [x] Map screen (placeholder)
- [x] Favorites screen
- [x] Info screen
- [x] Tree detail bottom sheet

### Phase 2: Map Integration 🚧 (Next)
- [ ] Integrate MapLibre with AndroidView
- [ ] Display tree markers on map
- [ ] Marker clustering for performance
- [ ] Center map on Vienna by default
- [ ] Handle marker tap to show details
- [ ] User location marker (optional)

### Phase 3: Enhanced Features
- [ ] Filter trees by species
- [ ] Filter by height range (slider)
- [ ] Filter by district
- [ ] Search functionality
- [ ] Distance-based filtering
- [ ] Sort favorites
- [ ] Private notes for trees

### Phase 4: Polish & Optimization
- [ ] Performance optimization
- [ ] Accessibility improvements
- [ ] Localization (German + English)
- [ ] Widget support
- [ ] Share tree information
- [ ] Export favorites

## Contributing

This is a learning project demonstrating modern Android development practices. Contributions, suggestions, and feedback are welcome!

### Code Style

- Follow [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html)
- Use meaningful variable and function names
- Add KDoc comments for public APIs
- Keep functions small and focused
- Prefer immutability

### Commit Guidelines

- Use clear, descriptive commit messages
- Reference issues when applicable
- Keep commits atomic and focused

## License

This project is open source and available under the MIT License (to be added).

### Data License

Tree data from Stadt Wien is licensed under:
**Creative Commons Attribution 4.0 International (CC BY 4.0)**

## Acknowledgments

- **Stadt Wien** for providing open government data
- **OpenStreetMap** contributors for map data
- **MapLibre** for the mapping library
- Google for Material Design and Jetpack libraries
- The Android developer community

## Contact & Support

This is an educational project. For questions or issues, please use the GitHub issue tracker (when repository is published).

---

**Made with ❤️ for Vienna**
