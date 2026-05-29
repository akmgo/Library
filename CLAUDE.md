# CLAUDE.md

## Project

**Library** — A SwiftUI + SwiftData reading tracker app for macOS & iOS. Track reading sessions, excerpts, and build a personal library.

- Target: macOS 26.4, iOS 26.4
- Swift 5.0, Xcode 26.x
- No CI/CD configured

## Build

```bash
# macOS
xcodebuild -project Library.xcodeproj -scheme Library -destination 'platform=macOS' build

# iOS Simulator
xcodebuild -project Library.xcodeproj -scheme Library -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Single Xcode project with two targets: `Library` (macOS + iOS via `#if os` guards) and `LibraryWidgetsExtension` (WidgetKit widgets).

## Architecture

```
Shared/           → Cross-platform: models, design tokens, services, components
macOS/            → macOS-only UI (NavigationSplitView + sidebar)
iOS/              → iOS-only UI (TabView + NavigationStack)
LibraryWidgets/   → 7 WidgetKit widgets
```

### Data Layer (SwiftData)

**Models**: `Book` ↔ `[ReadingSession]` (cascade), `Book` ↔ `[Excerpt]` (cascade), `UserConfig` (standalone singleton).

**Singletons** (all `@MainActor`):
- `SharedDatabase.shared` — ModelContainer provider, App Group `group.com.akram.library`
- `ReadingDataService.shared` — All CRUD, status transitions, session creation
- `ReadingTimerStore.shared` — `ObservableObject`, in-memory timer state (not persisted)
- `ImageCacheManager.shared` — NSCache-based cover image cache

**Calculators** (pure static methods, enum namespaces):
- `ReadingStatsCalculator` — `DashboardSnapshot`, momentum, heatmaps, gallery stats
- `ReadingValidation` — Input clamping and normalization

### Platform Guards

| Guard | Used for |
|---|---|
| `#if os(macOS) \|\| os(iOS)` | All Shared/ code |
| `#if os(macOS)` | All macOS/ UI, AppKit imports |
| `#if os(iOS)` | All iOS/ UI, UIKit imports, ImageIO downsampling |

Shared code never imports AppKit/UIKit directly — uses typealias bridges (`PlatformImage`).

### Design System

All in `Shared/Design/`: `AppColors` (semantic + adaptive), `AppSpacing` (4–64 scale), `AppRadius`, `AppTypography`, `AppComponentSizes`.

Common UI patterns: `GroupBox` + `NativeWidgetGroupBoxStyle()` (glass card), `BookCoverView` (cross-platform cover with caching), `ProgressBarView`, `.glassCard()` modifier.

## Key Patterns

- **iOS home screen**: `MobileHomeView` — `VStack` in `ScrollView` with cards: Hero → Dashboard → Momentum → Timer → Queue → Heatmap → Knowledge
- **Focus management**: `focusedReadingBookID` state routes a single focused book to Hero and Timer cards
- **Timer sheets**: Three `.sheet` modifiers (timed duration picker, completion with progress input, manual entry)
- **Data flow**: `@Query` arrays → `DashboardSnapshot` computed → individual card props
- **No ViewModels** — computed properties on View structs and static calculator methods

## File Naming

- macOS views: `*View.swift` (e.g., `HomeView.swift`)
- iOS views: `Mobile*View.swift` or `Mobile*Card.swift`
- Shared components: Descriptive PascalCase (`BookCoverView.swift`)
- Sheets: `Mobile*Sheet.swift`
