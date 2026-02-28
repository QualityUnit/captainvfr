# Documentation Gardening Task
Scan this Dart/Flutter repository for stale, outdated, or inaccurate documentation and fix it. Be conservative — only fix issues you are confident about. Leave a `<!-- TODO: ... -->` comment for anything ambiguous.
## Documentation Files to Scan
- `README.md` — project overview, features, development instructions, elevation data regeneration workflow
- Any files in `docs/` directory
## Scanning Checklist
### 1. Broken File References
- Search all markdown files for backtick-quoted paths (e.g., \``scripts/download_global_elevation_data.dart`\`), markdown links, and inline references to Dart source files.
- Verify each referenced file still exists at that path by reading the filesystem.
- If a file was moved, update the reference to the new location.
- If a file was deleted with no replacement, remove the reference and note the deletion.
- Pay special attention to the "Regenerating Global Elevation Data" section in `README.md` — verify all three script paths exist.
### 2. Script Accuracy
Verify the elevation data regeneration workflow in `README.md`:
| Expected Script | Expected Location | Purpose |
|---|---|---|
| `download_global_elevation_data.dart` | `scripts/` | Downloads SRTM data |
| `generate_5min_elevation_bundles_tin.dart` | `scripts/` | Generates TIN bundles |
Check that:
- Both scripts exist at the documented paths
- The documented commands (`dart scripts/...`) match the actual script names
- The AWS S3 sync command references the correct bucket and path structure
- The documented asset path (`assets/data/tiles/elevation_5min_tin/`) matches the actual directory structure
### 3. External Links
Verify all external links in `README.md`:
- Website: `https://captainvfr.com`
- Web App: `https://captainvfr.com/app/`
- iOS App Store link
- Android Play Store link
- MacOS Download link
**Note**: Do not attempt to fetch these URLs — just verify they are properly formatted markdown links. Leave a `<!-- TODO: verify link still active -->` if a link looks suspicious.
### 4. Feature List Accuracy
Compare the documented features in `README.md` against the actual codebase:
- Flight planning
- Weather information (TAF/METAR translation)
- Airport information
- TFR notifications
- Flight tracking
Search the `lib/` directory for evidence of each feature. If a feature is documented but no corresponding code exists, leave a `<!-- TODO: verify feature status -->` comment.
### 5. Broken Internal Links
Check all markdown links in both `[text](url)` and `[text][ref]` styles:
- For relative links (e.g., `[docs](docs/architecture.md)`), verify the target file exists.
- For heading anchors (e.g., `#development`), verify the heading exists in the target file.
- For external links, leave them as-is.
### 6. Stale Code Examples
Find code examples in documentation that reference Dart imports, classes, functions, or packages:
- Verify referenced symbols still exist in the codebase.
- Check that package names in examples match `pubspec.yaml` dependencies.
- Update examples if the API has changed; leave a `<!-- TODO: ... -->` if the replacement is unclear.
### 7. Directory Structure References
If any documentation describes the project structure (e.g., `lib/`, `assets/`, `scripts/`), verify:
- The documented directories exist
- Key subdirectories mentioned are still present
- The structure description matches reality
### 8. Build and Development Instructions
Verify any documented Flutter/Dart commands:
- `flutter run`
- `flutter build`
- `flutter test`
- `dart analyze`
- `dart scripts/...`
Check that these commands are appropriate for the project type (mobile app, web app, desktop app).
## Rules
- Only modify documentation files (`*.md`, `*.mdx`, `*.rst`).
- **NEVER** modify Dart source code (`.dart`), configuration files (`pubspec.yaml`, `analysis_options.yaml`), or CI workflows (`.github/workflows/*.yml`).
- When removing a stale reference, check if there is a replacement to link to.
- Preserve each document's structure, tone, heading hierarchy, and formatting.
- If unsure about a change, leave a `<!-- TODO: verify — [description] -->` comment rather than guessing.
- Add `<!-- Last gardened: YYYY-MM-DD -->` to sections you have verified or updated.
- Do not rewrite paragraphs for style — only fix factual inaccuracies and broken references.
- Do not add new sections or documentation — only maintain what already exists.
## Output
After making changes, provide a plain-text summary listing:
1. **Files modified** and what was changed in each.
2. **Issues found and fixed** (one line per issue).
3. **Issues requiring human decision** (left as `<!-- TODO -->` comments).
4. **Sections verified as up-to-date** (no changes needed).


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


The documentation gardening system is now ready. To use it:

1. Commit both files to the repository
2. Configure the required GitHub secrets:
   - KIRO_CLIENT_ID
   - KIRO_CLIENT_SECRET
   - KIRO_REFRESH_TOKEN
   - KIRO_PROFILE_ARN
   - AWS_ROLE_ARN (optional)
   - AWS_ACCESS_KEY_ID (optional)
   - AWS_SECRET_ACCESS_KEY (optional)
3. Set the AWS_REGION variable (defaults to us-east-1)

The workflow will run every Monday at 9am UTC, or can be triggered manually via the Actions tab.
