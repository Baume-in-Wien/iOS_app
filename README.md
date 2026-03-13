<div align="center">
<img width="200" height="200" alt="image" src="https://github.com/user-attachments/assets/ad52cc5a-5fd5-4481-92d8-f0d2aff88ae5" />
</div>

# Bäume in Wien - iOS

The iOS client for Bäume in Wien, an educational app that helps people explore and learn about Vienna's urban trees. It pulls data from the city's open data portal and turns it into something you can actually walk around with -- discover trees, identify leaves, play rallies with friends or classmates, and keep track of what you've found.

## What it does

**Interactive tree map** -- Displays around 200,000 trees from Vienna's open data, with species-specific icons and clustering so the map stays usable. Tap any tree to see details like height, trunk circumference, year planted, and location.

**Solo explorer** -- Generates missions to find specific trees within a configurable radius (500m to 5km). Walk there, snap a photo, complete the mission.

**Multiplayer rallies** -- Solo rallies, student rallies for classrooms, and teacher rallies with a dashboard. Join via QR code, compete on real-time leaderboards, collect species, and build a digital herbarium along the way.

**Augmented reality** -- Overlays tree information on the camera feed based on your location.

**Leaf classifier** -- Point your camera at a leaf and a CoreML model tries to identify the species. Covers 200+ tree species with confidence scoring.

**Virtual pets** -- Adopt a squirrel, hedgehog, or other critter. Discovering trees feeds them, rally participation makes them happy. They level up and unlock accessories.

**Achievements** -- 24+ trophies across categories like species discovery, exploration distance, rally wins, and community contributions.

**Search and favorites** -- Full-text search by species, location, or district. Save your favorite trees.

**Community** -- Submit new trees, upload photos, and go through a verification workflow. User profiles with role-based permissions.

**Statistics** -- Track trees discovered, unique species collected, distance walked, and rally performance.

## Tech stack

| Area | Technology |
|---|---|
| UI | SwiftUI (iOS 17+) |
| Design | Custom "Liquid Glass" styling |
| Font | Host Grotesk |
| Persistence | CoreData + UserDefaults |
| Backend | Supabase (PostgreSQL) |
| Tree data | Vienna Open Data WFS API + Cloudflare R2 CDN cache |
| Location | MapKit + CoreLocation |
| ML | CoreML + Vision |
| AR | ARKit |
| Networking | URLSession + Supabase Swift SDK |
| Concurrency | async/await + @Observable |

## Project structure

```
baeumeinwien/
├── App/                  Global app state (@Observable)
├── Models/               Data models (Tree, Rally, Pet, Achievement, ...)
├── Views/
│   ├── Map/              Tree map and detail sheet
│   ├── Explorer/         Solo explorer mode
│   ├── AR/               Augmented reality view
│   ├── Rally/            Rally system (create, join, play, leaderboard, herbarium)
│   ├── Pet/              Virtual pet views
│   ├── LeafScanner/      Leaf classification camera
│   ├── Achievements/     Trophy gallery
│   ├── Community/        Tree submissions
│   ├── Search/           Tree search
│   ├── Auth/             Login and registration
│   └── Components/       Reusable UI components
├── Services/             API, ML, location, and other service classes
├── Persistence/          CoreData stack
├── Fonts/                Custom font files
└── LeafClassifier.mlpackage/
```

## Getting started

1. Clone the repo
2. Open `baeumeinwien.xcodeproj` in Xcode 15+
3. Set up your Supabase credentials in `SupabaseService.swift`
4. Build and run on a simulator or device (iOS 17+)

## Data sources

- **City of Vienna Open Data** -- Tree cadastre WFS API (~200,000 trees)
- **Wikipedia** -- Species descriptions
- **Cloudflare R2 CDN** -- Cached district data for faster loading

## Support
- **Email**: support@treesinvienna.eu
- **Issue**: <a href="https://github.com/Baume-in-Wien/iOS_app">Create Issue </a>

## License

All rights reserved.
Made with ❤️ by Paulify Dev.
