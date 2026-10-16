# SyntaxCircus.Godot.AgeAssurance

Reusable Godot 4.7.2 age signals for iOS and Google Play. No app-specific age policy, account, legal text, save format or UI. No calls happen at plugin construction. Explicit `await provider.check(minimum_age, allow_prompt)` returns `status`, `eligibility`, `restriction`, `approval`, and regulatory `requirements` (obligations, not pending consent).

`status`: shared/declined/unavailable/verification_required/recheck_required. `eligibility`: eligible/below_minimum/unknown. `restriction`: empty/below_minimum/verification_required/approval_required/recheck_required. Approval remains independent of age. Unknown is never proof of adulthood. A successful silent Google response that loses previously shared bounds needs an explicit access recheck; it is not proof of either optional refusal or mandatory verification. A confirmed optional decline clears only this recheck restriction. The fake provider runs the same normalizer and supports held asynchronous results. Runtime data stays in memory; never log or upload it. No DOB, declaration source or platform install ID is read.

## Build and consume

- Godot tests: `godot --headless --path . --script res://tests/test_age_assurance.gd`.
- Android: JDK 17, Android SDK 36, Gradle 8.11.1; `gradle --no-daemon -p android :plugin:assembleDebug :plugin:assembleRelease`. Official Play Age Signals dependency 0.0.4, minSdk 24. Installations not managed by Play may return unavailable.
- `./publish.ps1 -GodotPath <godot> -DryRun` runs native and Godot tests, builds both Android AARs and creates `dist/<version>/` with the addon ZIP and SHA256 manifest. Set JDK17/SDK36 through JAVA_HOME/ANDROID_HOME. PowerShell7 and Python3 are required. The checked-in Gradle8.11.1 wrapper supplies Gradle. Optional `-Version X.Y.Z` stamps the packaged plugin without editing source; the default comes from plugin.cfg. Existing release folders are never overwritten. This command does not push, tag or upload.
- `python scripts/release.py` packages existing Android builds. `--version`, `--output` and `--source-commit` support release automation; the manifest records the tagged commit, archive hash and every payload hash. `--source-only` is for headless integration tests only and MUST be rejected by mobile release checks.
- Consumers extract the distribution without modifying it. Enable `addons/syntaxcircus_age_assurance/plugin.cfg`. Exclude bin/** and plugin.gd/plugin.cfg/export_plugin.gd from the PCK; keep runtime GDScript. Android export plugin supplies the bridge AAR and Maven dependency.
- iOS: release includes sources under `third_party/syntaxcircus_age_assurance/ios`. Run its `build.sh CONSUMER_APP_PATH` on a Mac with an iOS 26.4+ SDK and matching configured Godot source in GODOT_SOURCE. The native archive uses the release-template ABI; use `--export-release` with the matching engine template, even for development-signed device previews. It installs `ios/plugins/age_assurance`; enable `plugins/SyntaxCircusAgeAssurance=true`, the Declared Age Range capability on the Apple App ID, and `com.apple.developer.declared-age-range=true` in the signed app/profile. Regenerate provisioning profiles. Link framework weakly; deployment remains iOS 15. Swift runtime is linked by the plugin. Verify in a signed sandbox build, including an older OS.

## Lifecycle and policy

Check before honoring cached acceptance or enabling optional services. Call with prompting allowed on initial launch or explicit Recheck; call silently on foreground. User interaction can take time; the bridge deadline is 120 seconds and stale replies are discarded. Consumers must prevent the same pending check from authorizing stale navigation/deletion state.

Apple has no documented silent age-range query. Silent checks inspect regulatory requirements; explicit Recheck obtains a new range. Apple-required sharing cannot fall back to manual entry. Google silent checks retrieve previously shared age signals without asking access again. Do not repeatedly ask users who declined optional sharing. Gate cached acceptance using persistent restriction categories: failures cannot clear a known restriction. Resolving an approval restriction needs explicit approval, not just eligible age.

Age assurance is a platform signal, not identity verification or a complete legal compliance product. Required significant-update parental consent/adult acknowledgement are exposed as obligations; apps must configure and implement update workflows if applicable before shipping. API data cannot be used for advertising, profiling or analytics. No backend revocation ingestion, PermissionKit workflow or custom parent account is included. Consult official documentation and review your release obligations.

https://developer.apple.com/support/age-assurance/
https://developer.android.com/google/play/age-signals/overview

## GitHub releases

The Release workflow matches SyntaxCircus.Godot.GamesServices: pushing an existing `vX.Y.Z` tag starts the build; a manual workflow run can also publish an existing stable tag. It checks out that exact tag, runs packaging/JUnit/Godot tests, builds debug and release AARs, stamps X.Y.Z into the ZIP, and creates the GitHub release with the ZIP and manifest. Versions in the manifest remain plain X.Y.Z for compatibility with existing consumers; release URLs use vX.Y.Z. The write-enabled publishing job only receives the tested assets. Action revisions and the Godot archive checksum are pinned to the same values as GamesServices.

Commit and push the library/workflow before tagging a release. The workflow never creates tags automatically, and local `publish.ps1` never uploads. GitHub Actions itself must be enabled for the repository. iOS source is included for consumer-side Mac compilation against matching Godot headers; this Windows release workflow does not compile or validate a signed iOS app.
