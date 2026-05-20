# AGENTS.md

## Project Context

This is a SwiftUI / SwiftData multi-platform project with macOS, iOS, and shared code.

The project is being refactored from an old reading app with ebook reader features into a V1 reading record app.

The new V1 app is not an ebook reader.

The V1 app focuses on:

- books
- reading status
- reading progress
- reading sessions
- reading duration
- reading timer
- manual reading time input
- minimal book annotations
- basic user configuration
- existing visual style where it is not tied to reader logic

The source of truth for V1 foundation rules is:

- docs/V1_FOUNDATION.md

The source of truth for the migration sequence is:

- docs/MIGRATION_PLAN.md

Always read both files before modifying code.

## Permission Model

The user grants permission to inspect, edit, move, delete, and refactor project files as needed for this migration.

You do not need to ask for confirmation before editing files.

However, if a task requires manual Xcode actions that are safer or more correct outside code editing, stop and clearly tell the user what to do.

Examples of manual actions:

- removing or adding target membership
- changing Xcode schemes
- changing build phases
- changing signing settings
- resolving project file conflicts
- selecting the correct destination or simulator
- cleaning DerivedData if build artifacts cause stale errors
- running Xcode build if CLI build is unreliable

## Main Goal

Perform a continuous migration from the old reader-based project to the V1 reading record foundation.

The first migration goal is:

1. Remove or isolate all ebook-reader-related code from macOS, iOS, and shared code.
2. Refactor shared data models to match docs/V1_FOUNDATION.md.
3. Refactor shared design foundations to match docs/V1_FOUNDATION.md.
4. Fix compile-breaking references caused by the migration.
5. Preserve mature UI structure and styling where possible, but do not redesign screens unless required to compile.

## Hard Boundaries

Do not implement or restore ebook reader features.

Remove or isolate old reader-related code, including:

- EPUB reader logic
- PDF reader logic
- TXT reader logic
- ebook file import and parsing logic
- BookFormat
- localFileName
- lastReadLocation
- totalCharacters
- spineWeightMap
- CFI-based location logic
- ReaderWindowManager as the default book-opening behavior
- any default behavior where clicking a book opens an ebook reader

Books should represent reading objects, not ebook files.

## Data Model Rules

The required V1 models are:

- Book
- ReadingSession
- BookAnnotation
- UserConfig
- Snippet
- SnippetCategory

The required V1 enums are:

- BookStatus
- ProgressUnit
- AnnotationType
- ReadingInputMode

### BookStatus

BookStatus must include exactly:

- unread
- finished
- reading
- abandoned
- planned

Chinese display names must be:

- unread: 未读
- finished: 已读
- reading: 在读
- abandoned: 弃读
- planned: 想读

Important:

- planned must display as 想读.
- Do not display planned as 计划阅读.

### ProgressUnit

ProgressUnit must include exactly:

- page
- percent
- chapter

### AnnotationType

AnnotationType must include exactly:

- excerpt
- note

### ReadingInputMode

ReadingInputMode must include exactly:

- timer
- manual

### Book

Book must represent a reading object.

Book must not include:

- localFileName
- format
- lastReadLocation
- totalCharacters
- spineWeightMap
- updatedAt

Book should include:

- id
- title
- author
- coverData
- createdAt
- status
- rating
- tags
- startDate
- finishDate
- lastReadAt
- progressUnit
- totalAmount
- currentAmount
- summary
- sessions
- annotations

Book.rating must be 0–7.

0 means unrated.

### ReadingSession

ReadingSession represents one real reading session.

ReadingSession is not a daily unique record.

ReadingSession must be bound to Book.

ReadingSession must include:

- id
- date
- inputMode
- startedAt
- endedAt
- duration
- progressUnit
- startAmount
- endAmount
- createdAt
- book

ReadingSession must not include:

- note
- comments
- annotation text

Timer mode:

- startedAt is captured when the user starts the timer.
- endedAt is captured when the user stops the timer.
- duration = endedAt - startedAt.
- date = start of day for startedAt.

Manual mode:

- user enters startedAt
- user enters duration
- endedAt is calculated as startedAt + duration
- date = start of day for startedAt

### BookAnnotation

BookAnnotation must remain minimal.

BookAnnotation must include only:

- id
- content
- type
- createdAt
- book

BookAnnotation must not include:

- page number
- chapter
- CFI
- user comment
- session relationship
- tags
- progress location

### UserConfig

UserConfig should include:

- dailyMinutesGoal
- yearlyBooksGoal
- libraryBooksGoal
- defaultProgressUnit
- updatedAt

UserConfig must not include:

- daily page goal
- daily progress goal

### Snippet

Keep Snippet and SnippetCategory.

Do not delete them.

They belong to the future generic excerpt module and should not be connected to the V1 reading-session flow during this migration.

## Design Foundation Rules

Follow docs/V1_FOUNDATION.md.

Use shared design tokens or foundation definitions for:

- colors
- typography
- radius
- spacing
- shadows
- component sizes
- status colors
- progress visuals
- semantic glass/material usage

Prefer Apple-native SwiftUI system materials, Liquid Glass, Material, or Visual Effect where appropriate.

Do not simulate glass manually with arbitrary fixed blur and rgba unless there is no native alternative.

Do not redesign all screens during this migration.

Preserve existing mature visual structure where it does not depend on reader logic.

## Target and Xcode Rules

This is an Xcode project.

Codex may edit Swift files, shared files, model files, and project-adjacent files.

If changes require manual Xcode target membership, build phase, scheme, signing, or package configuration changes, report the exact manual action needed instead of guessing.

When removing files:

- remove references from code
- if needed, tell the user which files should be removed from Xcode target membership
- do not silently assume target membership changes were completed

When the project file is risky to edit automatically, ask the user to perform the Xcode action manually.

## Work Style

This is a continuous migration task.

Do not stop after only writing a plan unless blocked by missing files, missing build information, or required manual Xcode actions.

Work in phases according to docs/MIGRATION_PLAN.md.

Make small, reviewable changes.

After each phase:

- summarize files changed
- summarize code removed
- summarize model changes
- list compile errors if any
- list manual Xcode actions required, if any

Do not introduce third-party dependencies unless explicitly required by the user.

Do not add unrelated features.

Do not perform broad UI redesign unless necessary to keep the app compiling after model changes.

## Build and Validation

Prefer validating with available project build commands.

If command-line build is not reliable because of Xcode scheme, signing, or target setup, tell the user to build in Xcode and report errors back.

When possible, use:

- xcodebuild -list
- xcodebuild -scheme <scheme> -destination 'platform=macOS' build

Only use a specific scheme after discovering it from the project.

Do not invent scheme names.

## Safety

Do not delete user content, assets, or design files unless clearly reader-specific and no longer referenced.

If uncertain whether a file is reader-specific or a reusable UI component, preserve it and mark it for later review.

Prefer isolating uncertain old reader files into a deprecated path or leaving TODO notes over deleting shared UI or data code blindly.