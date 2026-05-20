# MIGRATION_PLAN.md

# 阅读记录 App V1 迁移计划

## 0. 任务目标

将当前 SwiftUI / SwiftData 多端项目，从旧的阅读器型项目，迁移为 V1 阅读记录 App。

本次迁移是连续任务。Codex 可以直接执行，不需要每一步都等待用户确认。

但如果需要 Xcode 手动操作，必须明确告诉用户执行什么。

---

# 1. 迁移原则

## 1.1 保留

尽量保留：

- macOS app shell
- iOS app shell
- shared SwiftUI components
- mature visual style
- book gallery UI structure
- settings UI structure
- Snippet
- SnippetCategory
- BookAnnotation concept
- non-reader assets
- reusable design components

---

## 1.2 删除或隔离

删除或隔离：

- EPUB reader
- PDF reader
- TXT reader
- ebook file parser
- reader window manager as default book-opening behavior
- CFI location logic
- local ebook file fields
- high-precision EPUB progress fields
- old BookFormat
- old daily-only ReadingRecord logic

---

## 1.3 不做

本次迁移不要做：

- 大规模 UI 重设计
- 新功能扩张
- iCloud 同步
- 日历同步正式功能
- AI 总结
- 年度报告
- 阅读器替代方案
- 第三方依赖引入

---

# 2. Phase 0: Project Audit

## Goal

Inspect the project before editing.

## Instructions

Read:

- AGENTS.md
- docs/V1_FOUNDATION.md
- docs/MIGRATION_PLAN.md

Then inspect the repository.

## Required output

Produce an audit report listing:

1. Project structure.
2. macOS target-related source files.
3. iOS target-related source files.
4. shared source files.
5. model files.
6. reader-related files.
7. reader-related symbols.
8. references to BookFormat.
9. references to localFileName.
10. references to lastReadLocation.
11. references to totalCharacters.
12. references to spineWeightMap.
13. references to CFI.
14. references to ReaderWindowManager or equivalent reader-opening behavior.
15. Snippet-related files to preserve.
16. visual style files to preserve.
17. files likely requiring Xcode target membership changes.
18. recommended migration order.

## Editing

Do not modify files in this phase unless the user has explicitly asked to skip audit.

---

# 3. Phase 1: Remove or Isolate Reader Code

## Goal

Remove or isolate ebook-reader-related code from macOS, iOS, and shared code.

## Remove or isolate

- EPUB reader logic
- PDF reader logic
- TXT reader logic
- file import and parsing logic
- BookFormat
- localFileName
- lastReadLocation
- totalCharacters
- spineWeightMap
- CFI-based location logic
- ReaderWindowManager default behavior
- views whose only purpose is ebook reading

## Preserve

- Book gallery
- home/dashboard visual components when not reader-dependent
- settings
- snippets
- annotations
- shared visual components
- models that will be refactored in Phase 2

## Behavior change

Book click behavior should no longer open an ebook reader.

If a view currently opens the reader, replace or stub behavior with one of:

- open book detail
- no-op with TODO
- placeholder action for future reading timer

Do not implement full new UI in this phase.

## After phase output

Summarize:

- files changed
- files removed or isolated
- reader symbols removed
- reader symbols still remaining
- manual Xcode actions required
- compile status

---

# 4. Phase 2: Refactor Data Models

## Goal

Refactor SwiftData models to match docs/V1_FOUNDATION.md.

## Required enums

- BookStatus
- ProgressUnit
- AnnotationType
- ReadingInputMode

---

## BookStatus

Must include exactly:

- unread
- finished
- reading
- abandoned
- planned

Display names:

- unread: 未读
- finished: 已读
- reading: 在读
- abandoned: 弃读
- planned: 想读

Do not display planned as 计划阅读.

---

## ProgressUnit

Must include exactly:

- page
- percent
- chapter

---

## AnnotationType

Must include exactly:

- excerpt
- note

---

## ReadingInputMode

Must include exactly:

- timer
- manual

---

## Book

Book must include:

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

Book must not include:

- updatedAt
- localFileName
- format
- lastReadLocation
- totalCharacters
- spineWeightMap

Book.rating must be 0–7.

0 means unrated.

---

## ReadingSession

Create or refactor ReadingSession.

ReadingSession must represent one real reading session.

It must include:

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

ReadingSession must be related to Book.

ReadingSession must not include note.

ReadingSession must not be a daily unique record.

---

## BookAnnotation

BookAnnotation must include only:

- id
- content
- type
- createdAt
- book

Do not include:

- page number
- chapter
- CFI
- user comment
- session relationship
- tags
- progress location

---

## UserConfig

UserConfig must include:

- dailyMinutesGoal
- yearlyBooksGoal
- libraryBooksGoal
- defaultProgressUnit
- updatedAt

UserConfig must not include:

- dailyPagesGoal
- daily progress goal

---

## Snippet

Preserve:

- Snippet
- SnippetCategory

Do not connect Snippet to V1 reading-session flow.

## After phase output

Summarize:

- changed model files
- removed fields
- added fields
- updated relationships
- compile-breaking references to fix later

---

# 5. Phase 3: Refactor Design Foundation

## Goal

Create or refactor shared design foundation according to docs/V1_FOUNDATION.md.

## Required foundation areas

- colors
- typography
- radius
- spacing
- shadows
- component sizes
- status colors
- progress visuals
- semantic glass/material usage

## Rules

Prefer Apple-native SwiftUI materials and system effects.

Do not fake glass everywhere with arbitrary blur and rgba.

Do not redesign screens.

Build shared foundations first.

Existing views can be migrated gradually.

## After phase output

Summarize:

- created design foundation files
- updated design token names
- old style files preserved
- old style files deprecated
- views that still use old style constants

---

# 6. Phase 4: Compile Repair

## Goal

Make the project compile after reader removal, model refactor, and design foundation refactor.

## Rules

- Do not add new product features.
- Do not redesign screens.
- Replace broken model references with new V1 fields.
- If an old screen depends heavily on removed reader logic, stub or simplify that part.
- Keep Snippet-related code if possible.
- Keep visual structure if possible.

## Common fixes

Old references to remove or replace:

```text
BookFormat
localFileName
format
lastReadLocation
totalCharacters
spineWeightMap
locationCFI
ReadingRecord
dailyReadingGoal
dailyPagesGoal
ReaderWindowManager
```

Likely replacements:

```text
BookFormat → remove
format → remove
localFileName → remove
lastReadLocation → remove
totalCharacters → remove
spineWeightMap → remove
locationCFI → remove
ReadingRecord → ReadingSession
dailyReadingGoal → dailyMinutesGoal
dailyPagesGoal → remove
ReaderWindowManager open behavior → book detail or placeholder
```

## Xcode manual action handling

If build fails because files remain in target membership after deletion:

Tell the user exactly:

- which file
- which target
- what to remove from target membership

If build fails because a file is missing from target membership:

Tell the user exactly:

- which file
- which target
- what to add to target membership

Do not guess project file edits if unsafe.

## After phase output

Summarize:

- compile command used
- build result
- remaining errors
- manual Xcode actions required
- next recommended phase

---

# 7. Phase 5: UI Migration Preparation

## Goal

Do not perform full UI migration unless explicitly asked.

Only prepare notes.

## Output

List:

1. screens that still use old reader assumptions
2. screens that can be preserved as-is
3. screens that should be redesigned later
4. places where reading timer should be integrated later
5. places where manual reading session creation should be integrated later

---

# 8. Manual Xcode Actions Expected

The user is using Codex client and Xcode.

Codex should expect some manual Xcode actions.

When necessary, ask the user to perform:

```text
Remove deleted reader files from target membership.
Remove deleted reader files from Build Phases > Compile Sources.
Add new model or foundation files to macOS target.
Add new shared files to iOS target if needed.
Check scheme selection.
Run Product > Clean Build Folder.
Build macOS target in Xcode.
Build iOS target in Xcode.
Report remaining compiler errors.
```

Codex should not repeatedly request confirmation for normal file edits.

Only stop for manual Xcode actions or missing information.

---

# 9. Continuous Task Instruction

When the user asks to start migration, execute phases continuously in order:

1. Audit.
2. Remove or isolate reader code.
3. Refactor data models.
4. Refactor design foundation.
5. Repair compile errors.
6. Report manual Xcode tasks if needed.

Do not stop after audit unless blocked.

Do not wait for approval after each small change.

Do not redesign UI.

Do not add unrelated features.

---

# 10. Final Target State

After this migration, the project should have:

- no active ebook reader logic
- no BookFormat
- no reader location fields
- no high-precision EPUB progress cache fields
- no default reader-opening behavior
- V1 Book model
- V1 ReadingSession model
- V1 BookAnnotation model
- V1 UserConfig model
- preserved Snippet model
- shared design foundation
- project compiling or a clear list of Xcode manual fixes required
