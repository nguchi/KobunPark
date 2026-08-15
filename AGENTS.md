# KobunPark — Codex Project Instructions

## 1. Project purpose

KobunPark is a local-first syntax and data transformation utility for personal daily use.

The product should make small, frequent technical tasks finish in seconds:

- paste or open source text;
- detect or select its format;
- transform, validate, or preview it;
- copy or export the result.

Prioritize a small, reliable tool over a feature-heavy application.

## 2. Product name

- Product and display name: `KobunPark`
- Repository and folder name: `kobunpark`
- Bundle identifier: `jp.nguchi.KobunPark`
- Do not reintroduce the former name `KobunStudio`.

## 3. Target environment

- Primary development machine: Apple Silicon M3 MacBook Pro
- Primary IDE: Xcode
- Primary platform: macOS
- Secondary platforms, in order: iPadOS, then iOS
- Test devices: M4 iPad Air and iPhone
- Parallels Desktop with Windows 11 Pro is a secondary test environment only.
- Windows support is outside the first release unless the user explicitly changes scope.

## 4. Technical direction

- Use Swift and SwiftUI.
- Prefer a SwiftUI multiplatform project while optimizing the first usable release for macOS.
- Keep transformation logic independent from views and platform-specific APIs.
- Put reusable logic in `KobunCore` and shared UI in `KobunUI` when the project structure supports separate modules.
- Use platform-specific code only when a shared implementation would harm usability or reliability.
- Prefer Apple frameworks and the standard library over third-party dependencies.
- Before adding a production dependency, explain its purpose, maintenance risk, license, and native alternative.
- Use WebKit only where browser rendering is materially useful, such as offline KaTeX or Mermaid previews.
- Keep the core features usable offline.

## 5. MVP scope

Implement in this order:

1. JSON formatting, validation, and useful error display
2. URL component percent-encoding and decoding
3. LaTeX input with local preview
4. Regular-expression matching and replacement preview
5. macOS copy/paste workflow and keyboard shortcuts
6. CSV to Markdown table, HTML table, and XML
7. Base64, HTML entity, and JSON string escaping transformations

Undo/redo history is kept in memory only and must not persist user content across app launches.

The following are later-stage features and must not delay the MVP:

- JSON and YAML conversion
- reusable snippets
- menu-bar access
- drag and drop
- iPadOS layout
- iPhone share extension and App Intents
- Mermaid preview
- Excel formula and Power Query M formatting
- Ollama integration
- opt-in iCloud synchronization
- Windows version

Do not expand scope merely because a related feature is easy to add.

## 6. Architecture rules

- Views must not contain parsing or transformation business logic.
- Model transformations as deterministic functions where practical.
- Represent success and failure explicitly; never silently alter invalid input.
- Preserve the user's original input until they deliberately replace or clear it.
- Keep format detection advisory. The user must be able to override it.
- Avoid global mutable state.
- Prefer small types with clear responsibilities and names that describe intent.
- Add protocol abstractions only when there is a real substitution or testing need.
- Keep macOS-specific code isolated from shared core logic.

## 7. Privacy and security

- Treat clipboard data, opened files, logs, and snippets as potentially confidential.
- Do not send user content to a network service unless the user explicitly enables and invokes that feature.
- Do not automatically synchronize clipboard history.
- Synchronize only content the user explicitly saves and opts into syncing.
- Never log raw clipboard contents, document contents, secrets, tokens, or personal data.
- Do not commit credentials, signing material, provisioning profiles, `.env` files, or user-specific Xcode data.
- Bind any future Ollama integration to a user-configurable local endpoint and clearly disclose any non-local endpoint.
- Use secure Apple storage APIs for secrets if secrets become necessary.

## 8. User experience

- Optimize the main path for `input -> transform/preview -> copy`.
- Keep the macOS interface keyboard-friendly and accessible.
- Avoid modal dialogs for routine validation errors.
- Show errors close to the relevant input and include line/column information when available.
- Do not overwrite the clipboard without an explicit user action.
- Do not persist input or history by default.
- Preserve user work across harmless view or window changes.
- Provide undo and redo for in-memory edits and transformation actions.
- Use Japanese for user-facing text initially, while keeping localization possible.

## 9. Coding conventions

- Follow current Swift API Design Guidelines.
- Prefer Swift concurrency and structured concurrency for asynchronous work.
- Update UI-observable state on the appropriate actor.
- Avoid force unwraps and `try!` outside tests or provably safe constants.
- Use meaningful names; avoid unexplained abbreviations.
- Keep comments focused on intent, constraints, and non-obvious decisions.
- Do not perform broad refactors during a narrowly scoped feature or bug fix.
- Preserve unrelated user changes in a dirty worktree.

## 10. Tests and verification

- Add unit tests for every parser, formatter, validator, and converter.
- Include normal, empty, malformed, Unicode/Japanese, and boundary inputs where relevant.
- Add regression tests before or with bug fixes.
- Prefer exact deterministic assertions for transformation output.
- Use UI tests only for critical end-to-end workflows that unit tests cannot cover.
- Before editing build commands, inspect the actual project and schemes with `xcodebuild -list`.
- Run the narrowest relevant tests first, then the broader available suite.
- If a test or build cannot run, report the exact command, failure, and what remains unverified.
- Do not claim success based only on code inspection when executable verification is available.

## 11. Working method for Codex

- Read this file and inspect the existing project before proposing structural changes.
- For a complex or ambiguous request, state assumptions and present a short prioritized plan before implementation.
- Ask only when missing information materially changes architecture, security, data handling, or destructive behavior.
- For routine implementation details within these constraints, make a reasonable choice and proceed.
- Search with `rg` or `rg --files` before using slower recursive tools.
- Make focused edits and use existing project patterns before introducing new ones.
- Explain meaningful tradeoffs directly, including complexity and maintenance cost.
- Update relevant documentation when behavior, architecture, setup, or scope changes.
- Record major architectural decisions in `docs/DECISIONS.md` when that file exists.
- Never rename the product, change platforms, add cloud processing, or widen MVP scope without explicit user approval.

## 12. Definition of done

A task is complete only when:

- the requested behavior is implemented within the agreed scope;
- relevant tests are added or updated and pass;
- the applicable target builds when the environment permits it;
- privacy and offline-first constraints remain intact;
- errors and edge cases are handled visibly;
- documentation is updated when needed;
- the final report states what changed, how it was verified, and any remaining limitation.

## 13. Current product decisions

- Apple-native development is preferred because macOS is the user's primary environment.
- SwiftUI is preferred over .NET MAUI and Tauri for the initial product.
- macOS ships first; iPadOS and iOS follow after the core workflow is stable.
- AI is not required for the MVP. Deterministic transformation takes priority.
- Local-first and explicit user control take priority over automatic collection or synchronization.
- The Xcode marketing version is user-controlled and is currently `0`; Codex must not change it without explicit user instruction.
- The Xcode build number uses a Japan-time timestamp in `YYYYMMDDHHMMSST` form and should be refreshed when preparing an identifiable development build.
- The copyright holder is `nguchi`; the project is provisionally all-rights-reserved until the user explicitly selects replacement license terms.
