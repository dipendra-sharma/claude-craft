# Crashes inside a third-party library

Read this when the crash site is not in your own package. The goal is never to patch the
library — it is to learn what precondition the library assumes so you can satisfy it at
**your** call site.

## 1. Pin the exact version

The version decides whether a known fix already exists, so read it from the lock file rather
than the manifest.

| Platform | File | Command |
|---|---|---|
| Android (Gradle) | `libs.versions.toml`, `build.gradle` | `./gradlew dependencies` |
| iOS (CocoaPods) | `Podfile.lock` | `cat Podfile.lock` |
| iOS (SPM) | `Package.resolved` | `cat Package.resolved` |
| Flutter | `pubspec.lock` | `cat pubspec.lock` |
| React Native | `yarn.lock`, `package-lock.json` | `yarn list <pkg>` |

Map the crashing package to a library: `com.google.android.gms.*` → Play Services,
`com.squareup.okhttp3.*` → OkHttp, `io.reactivex.*` → RxJava, `androidx.*` → Jetpack (report
to Google). Unknown prefix → search `site:mvnrepository.com <package.prefix>`.

## 2. Read the source — do not guess

**Local cache first.** No network, and it is the exact build you shipped.

```bash
find ~/.gradle -name "*<library>*sources*" -type f   # Android; then: jar -xf <sources.jar>
~/.cocoapods/repos/ ; ~/Library/Caches/CocoaPods/Pods/
~/.pub-cache/hosted/pub.dev/<package>-<version>/lib/
./node_modules/<package>/
```

**Then GitHub**, at the tag matching your version — not `main`, which may already contain the
fix and mislead you. `https://github.com/search?q=<ClassName>+<methodName>&type=code`.

**Then decompile**, when no source exists:

```bash
jadx --deobf <library.aar|classes.dex>          # Android, readable Java/Kotlin
class-dump -H <Framework.framework/Framework>   # iOS Objective-C headers
otool -tV <binary> | grep -A 30 <methodName>    # iOS disassembly
nm -gU <binary> | grep <MethodName>             # iOS symbols
strings libapp.so | grep <ClassName>            # Flutter AOT, quick scan
```

What you are looking for: the precondition the crashing method asserts, whether the crash is a
missing guard on our side or a defensive assertion inside the library, and which public API on
our side reaches that internal path.

## 3. Check whether it is already known

Search in parallel with the library name, your version, and the exception:

```
site:github.com <library> "<ExceptionType>" "<message fragment>"
github.com/<org>/<repo>/issues?q=<ExceptionType>
github.com/<org>/<repo>/releases        # and CHANGELOG.md — look for a fix after your version
site:stackoverflow.com <library> <ExceptionType>
```

For Google SDKs also check `issuetracker.google.com` and the migration guide for your version.

## 4. Choose the strategy

| Situation | Fix |
|---|---|
| Our call passes invalid state (null, wrong type, bad lifecycle) | validate at our call site before calling in |
| Known library bug, fixed upstream | bump to the **minimum** version containing the fix |
| Known library bug, no fix yet | guard our call site so the broken path is unreachable; file or upvote upstream |
| Hardware/OS-specific (GPU OOM, driver) | detect the constraint, skip or degrade gracefully |
| Correct usage, no fix, negligible impact | document as won't-fix and mute in Crashlytics |

## 5. Turn the reading into a change on our side

- Library asserts a non-null parameter → validate at our boundary, not in a catch block
- Library has an internal state machine → call only from states it accepts
- Library does synchronous I/O → call it from the right dispatcher or queue
- Library caches across calls → respect its initialization order before first use
- Decompiled code reveals a supported workaround API → adopt it

Never patch decompiled output and ship it. The insight goes into our call sites.
