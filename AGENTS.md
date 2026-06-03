# AGENTS.md

## Project Context

This is now an iOS-only SwiftUI + SwiftData project.

The app is a quiet book record app. It is not a reader, not a multi-platform app, not a widget system, and not a general inspiration/snippet app.

The product focuses only on:

- books
- manual reading duration records
- book excerpts
- book notes

## Product Boundaries

Do not implement or restore:

- macOS app code
- widgets
- Live Activities
- reader features
- EPUB/PDF/TXT parsing or reading
- timers or active reading sessions
- generic snippets unrelated to books
- CloudKit sync
- App Group shared storage
- backup/time-machine/data-health tools
- AI/export/calendar features

The app only records what the user manually enters.

## Current Source Structure

```text
Library/
  LibraryApp.swift
  Assets.xcassets
  Info.plist
  PrivacyInfo.xcprivacy

iOS/
  App/
  Models/
  Theme/
  Views/
  Sheets/
```

## Data Model

The app has three SwiftData models:

- `Book`
- `ReadingLog`
- `BookText`

`ReadingLog` is manual only. It stores a date, minutes, and optional page progress.

`BookText` stores only book-bound excerpts and notes.

## UI Direction

The interface should feel premium, quiet, and restrained.

Prefer:

- clear hierarchy
- warm paper-like background
- calm cards
- native iOS navigation
- simple forms
- minimal animation

Avoid:

- decorative effects
- heavy glass everywhere
- dense dashboards
- large chart systems
- category sprawl
- custom navigation systems

## Work Style

You may inspect, edit, move, delete, and refactor files without asking for confirmation.

Keep the project compiling after each meaningful phase.

Validate with:

```bash
xcodebuild -scheme Library -destination 'generic/platform=iOS' build
```

Do not touch `.claude` or Claude-related files.
