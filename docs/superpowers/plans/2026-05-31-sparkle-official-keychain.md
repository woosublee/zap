# Sparkle Official Keychain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sparkle EdDSA Keychain 사용 기준을 공식 Sparkle CLI 항목으로 정리하고, release code signing identity 기본값을 `zap`으로 바꾸며, README와 테스트를 이 기준에 맞춘다.

**Architecture:** 코드 변경은 build/release 설정과 문서에만 한정한다. `Makefile`은 signing identity와 Sparkle account의 source of truth가 되고, `README.md`는 Sparkle CLI의 고정 label/service 및 하루 1회 기본 체크 주기를 설명한다. `UpdateMetadataTests`는 `Info.plist` metadata와 `Makefile` 기본값이 설계와 어긋나지 않도록 문자열 회귀 테스트를 추가한다.

**Tech Stack:** Swift XCTest, GNU Make/macOS shell tools, Sparkle 2.9.2 CLI, macOS Keychain `security` CLI.

---

## File Structure

- Modify: `Makefile`
  - `RELEASE_CODESIGN_IDENTITY` 기본값을 `Zap Local`에서 `zap`으로 변경한다.
  - `SPARKLE_ACCOUNT ?= com.woosublee.Zap.sparkle.ed25519`는 유지한다.
  - `check-eddsa-key`의 공식 Sparkle service/account 검증은 유지한다.
- Modify: `README.md`
  - Sparkle release flow 설명에서 code signing identity를 `zap`으로 바꾼다.
  - Sparkle CLI가 고정하는 `service`/`label`과 Zap이 선택한 `account`를 설명한다.
  - `SUUpdateCheckInterval`을 설정하지 않아 Sparkle 기본값인 하루 1회 체크를 사용한다고 문서화한다.
- Modify: `Tests/ZapAppTests/UpdateMetadataTests.swift`
  - `Makefile`이 `RELEASE_CODESIGN_IDENTITY ?= zap`을 포함하는지 검증한다.
  - `Makefile`이 `SPARKLE_ACCOUNT ?= com.woosublee.Zap.sparkle.ed25519`를 포함하는지 검증한다.
  - `Makefile`이 공식 Sparkle Keychain service `https://sparkle-project.org`를 확인하는지 검증한다.
  - `Info.plist`가 `SUUpdateCheckInterval`을 설정하지 않는지 검증한다.
- Existing: `docs/superpowers/specs/2026-05-31-sparkle-official-keychain-design.md`
  - 승인된 설계 문서이다. 구현 중 수정하지 않는다.

---

### Task 1: Add release metadata regression tests

**Files:**
- Modify: `Tests/ZapAppTests/UpdateMetadataTests.swift`

- [ ] **Step 1: Replace `UpdateMetadataTests.swift` with expanded tests**

Replace the entire file with this content:

```swift
import Foundation
import XCTest

final class UpdateMetadataTests: XCTestCase {
    func testInfoPlistDeclaresSparkleKeysAndBuildTag() throws {
        let plist = try loadInfoPlist()

        XCTAssertEqual(plist["SUFeedURL"] as? String, "https://woosublee.github.io/zap/appcast.xml")
        XCTAssertEqual(plist["SUPublicEDKey"] as? String, "AHxDbDyUOqSlujzhZxsiHr89OwuBOgBiacMlFdCHTHs=")
        XCTAssertEqual(plist["SUEnableAutomaticChecks"] as? Bool, true)
        XCTAssertEqual(plist["SUAutomaticallyUpdate"] as? Bool, false)
        XCTAssertEqual(plist["ZapBuildTag"] as? String, "local-unknown")
    }

    func testInfoPlistUsesSparkleDefaultUpdateCheckInterval() throws {
        let plist = try loadInfoPlist()

        XCTAssertNil(plist["SUUpdateCheckInterval"])
    }

    func testMakefileWritesBuildTagIntoBundle() throws {
        let makefile = try loadMakefile()

        XCTAssertTrue(makefile.contains("BUILD_TAG ?="))
        XCTAssertTrue(makefile.contains("plutil -replace ZapBuildTag -string \"$(BUILD_TAG)\""))
    }

    func testMakefileUsesZapReleaseSigningIdentity() throws {
        let makefile = try loadMakefile()

        XCTAssertTrue(makefile.contains("RELEASE_CODESIGN_IDENTITY ?= zap"))
        XCTAssertTrue(makefile.contains("LOCAL_CERTIFICATE_IDENTITY ?= $(RELEASE_CODESIGN_IDENTITY)"))
    }

    func testMakefileUsesOfficialSparkleKeychainAccount() throws {
        let makefile = try loadMakefile()

        XCTAssertTrue(makefile.contains("SPARKLE_ACCOUNT ?= com.woosublee.Zap.sparkle.ed25519"))
        XCTAssertTrue(makefile.contains("security find-generic-password -s \"https://sparkle-project.org\" -a \"$(SPARKLE_ACCOUNT)\""))
    }

    private func loadInfoPlist() throws -> [String: Any] {
        let data = try Data(contentsOf: URL(fileURLWithPath: "Info.plist"))
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: Any])
    }

    private func loadMakefile() throws -> String {
        try String(contentsOfFile: "Makefile", encoding: .utf8)
    }
}
```

- [ ] **Step 2: Run the focused failing test command**

Run:

```bash
swift test --filter UpdateMetadataTests
```

Expected:

- `testMakefileUsesZapReleaseSigningIdentity` fails because `Makefile` still contains `RELEASE_CODESIGN_IDENTITY ?= Zap Local`.
- Other tests may pass.

- [ ] **Step 3: Commit the failing regression tests**

Run:

```bash
git add Tests/ZapAppTests/UpdateMetadataTests.swift
git commit -m "test: cover Sparkle release metadata"
```

Commit message body must end with:

```text
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

---

### Task 2: Change release signing identity default to zap

**Files:**
- Modify: `Makefile`
- Test: `Tests/ZapAppTests/UpdateMetadataTests.swift`

- [ ] **Step 1: Update the Makefile identity default**

In `Makefile`, change this line:

```make
RELEASE_CODESIGN_IDENTITY ?= Zap Local
```

To:

```make
RELEASE_CODESIGN_IDENTITY ?= zap
```

Do not change this line:

```make
LOCAL_CERTIFICATE_IDENTITY ?= $(RELEASE_CODESIGN_IDENTITY)
```

Do not change this line:

```make
SPARKLE_ACCOUNT ?= com.woosublee.Zap.sparkle.ed25519
```

- [ ] **Step 2: Run the focused metadata tests**

Run:

```bash
swift test --filter UpdateMetadataTests
```

Expected:

- All `UpdateMetadataTests` pass.

- [ ] **Step 3: Commit the Makefile change**

Run:

```bash
git add Makefile
git commit -m "build: use zap signing identity"
```

Commit message body must end with:

```text
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

---

### Task 3: Update README Sparkle release flow

**Files:**
- Modify: `README.md:130-197`

- [ ] **Step 1: Replace the Sparkle updates section**

In `README.md`, replace the section from this heading:

```markdown
## Sparkle updates and release flow
```

through the paragraph ending with:

```markdown
Upload `dist/Zap-0.1.1.zip` to the GitHub Release matching `v0.1.1`, then publish `dist/appcast.xml` to the `SUFeedURL` location so Sparkle can discover the update.
```

with this content:

```markdown
## Sparkle updates and release flow

Zap uses Sparkle 2.9.2 for automatic updates. Update archives referenced by the appcast are verified with Sparkle EdDSA signatures, while the local production/release build path uses a self-signed macOS code signing identity named `zap`.

Development builds use ad-hoc signing by default with `CODESIGN_IDENTITY=-`. Release-oriented targets use `RELEASE_CODESIGN_IDENTITY ?= zap`.

Sparkle automatic checks are enabled, automatic installs are disabled, and Zap does not set `SUUpdateCheckInterval`. Sparkle therefore uses its default automatic check interval of once per day.

### One-time local setup

Create the local self-signed signing certificate:

```sh
make create-local-certificate
```

Generate the Sparkle EdDSA key in Keychain:

```sh
make generate-eddsa-key
```

Because of Sparkle's official tool behavior, the private key is stored in Keychain using Sparkle's fixed label and service. Zap only customizes the Sparkle account name:

- label: `Private key for signing Sparkle updates`
- service: `https://sparkle-project.org`
- account: `com.woosublee.Zap.sparkle.ed25519`

The Sparkle EdDSA private key is not stored in this repository.

### Verification

Check that the local signing certificate exists:

```sh
make check-local-certificate
```

Check that the Sparkle EdDSA private key exists in Keychain and matches the `SUPublicEDKey` committed in `Info.plist`:

```sh
make check-eddsa-key
```

The matching public key is configured in the app's `Info.plist` as `SUPublicEDKey`:

```text
AHxDbDyUOqSlujzhZxsiHr89OwuBOgBiacMlFdCHTHs=
```

`SUFeedURL` points to:

```text
https://woosublee.github.io/zap/appcast.xml
```

### Generate release archive and appcast

Generate the Sparkle archive and appcast for a tagged release:

```sh
make appcast VERSION=0.1.1 BUILD_NUMBER=2 BUILD_TAG=v0.1.1
```

This creates ignored release artifacts:

- `dist/Zap-0.1.1.zip`
- `dist/appcast.xml`

Upload `dist/Zap-0.1.1.zip` to the GitHub Release matching `v0.1.1`, then publish `dist/appcast.xml` to the `SUFeedURL` location so Sparkle can discover the update.
```

- [ ] **Step 2: Verify README no longer documents Zap Local**

Run:

```bash
rg -n "Zap Local|RELEASE_CODESIGN_IDENTITY \?= Zap Local" README.md Makefile
```

Expected:

- No matches.

- [ ] **Step 3: Commit the README update**

Run:

```bash
git add README.md
git commit -m "docs: clarify Sparkle release setup"
```

Commit message body must end with:

```text
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

---

### Task 4: Verify local Sparkle and signing setup

**Files:**
- No source changes expected.

- [ ] **Step 1: Run the full Swift test suite**

Run:

```bash
swift test
```

Expected:

- All tests pass.

- [ ] **Step 2: Verify the Sparkle EdDSA key**

Run:

```bash
make check-eddsa-key
```

Expected:

- Command prints the public key:

```text
AHxDbDyUOqSlujzhZxsiHr89OwuBOgBiacMlFdCHTHs=
```

- Command exits successfully.

- [ ] **Step 3: Verify the local signing certificate**

Run:

```bash
make check-local-certificate
```

Expected:

- Command exits successfully.
- Output ends with:

```text
Code signing identity works: zap
```

If this fails because the `zap` certificate does not exist, run:

```bash
make create-local-certificate
make check-local-certificate
```

Expected after creating the certificate:

```text
Code signing identity works: zap
```

- [ ] **Step 4: Confirm working tree status**

Run:

```bash
git status --short
```

Expected:

- No output.

---

## Self-Review

- Spec coverage:
  - Sparkle account remains `com.woosublee.Zap.sparkle.ed25519`: Task 1 and Task 4 verify it.
  - No custom alias Keychain item: no task creates one.
  - `Zap Local` changes to `zap`: Task 1 tests it, Task 2 implements it, Task 3 documents it.
  - Default Sparkle daily interval is documented without adding `SUUpdateCheckInterval`: Task 1 tests absence, Task 3 documents it.
  - Validation commands are included: Task 4 covers `swift test`, `make check-eddsa-key`, and `make check-local-certificate`.
- Placeholder scan: no `TBD`, `TODO`, or unspecified implementation step remains.
- Type/name consistency:
  - `RELEASE_CODESIGN_IDENTITY`, `LOCAL_CERTIFICATE_IDENTITY`, `SPARKLE_ACCOUNT`, and `SUUpdateCheckInterval` names match the current files and spec.
