# Sparkle 공식 Keychain 항목 정리 설계

## 배경

Zap은 Sparkle 2.9.2로 macOS 자동 업데이트를 제공한다. 업데이트 archive는 Sparkle EdDSA 서명으로 검증하고, 로컬 release 빌드는 macOS code signing identity로 서명한다.

현재 `Info.plist`에는 다음 Sparkle metadata가 설정되어 있다.

- `SUFeedURL`: `https://woosublee.github.io/zap/appcast.xml`
- `SUPublicEDKey`: `AHxDbDyUOqSlujzhZxsiHr89OwuBOgBiacMlFdCHTHs=`
- `SUEnableAutomaticChecks`: `true`
- `SUAutomaticallyUpdate`: `false`

Keychain 조사 결과, 같은 `SUPublicEDKey`를 가리키는 Sparkle 공식 service 항목이 두 개 있었다.

- 유지할 항목: `service=https://sparkle-project.org`, `account=com.woosublee.Zap.sparkle.ed25519`
- 삭제한 중복 항목: `service=https://sparkle-project.org`, `account=AHxDbDyUOqSlujzhZxsiHr89OwuBOgBiacMlFdCHTHs=`

Sparkle CLI는 `label`과 `service`를 고정하고 `--account`만 커스터마이즈할 수 있다. 따라서 Zap은 공식 Sparkle CLI 항목 하나를 유지하고, 별도의 alias Keychain 항목은 만들지 않는다.

## 목표

1. Sparkle EdDSA private key 조회 기준을 공식 Sparkle CLI 항목으로 통일한다.
2. Keychain account는 일반적인 앱/용도 기반 이름인 `com.woosublee.Zap.sparkle.ed25519`를 사용한다.
3. 로컬 release code signing identity 이름을 `Zap Local`에서 `zap`으로 변경한다.
4. Sparkle 자동 업데이트 체크 주기는 별도 override 없이 기본값인 하루 1회를 사용한다고 문서화한다.

## 비목표

- Sparkle CLI가 지원하지 않는 custom Keychain label/service alias를 만들지 않는다.
- `SUPublicEDKey` 값은 변경하지 않는다.
- `SUFeedURL`은 변경하지 않는다.
- 자동 설치(`SUAutomaticallyUpdate`)는 활성화하지 않는다.
- 사용하지 않는 예전 기본 account `ed25519` 항목은 이번 변경의 필수 정리 대상에 포함하지 않는다.

## 설계

### Sparkle Keychain 항목

Zap이 사용하는 Sparkle EdDSA private key 항목은 다음 하나로 통일한다.

```text
label:   Private key for signing Sparkle updates
service: https://sparkle-project.org
account: com.woosublee.Zap.sparkle.ed25519
public:  AHxDbDyUOqSlujzhZxsiHr89OwuBOgBiacMlFdCHTHs=
```

`Makefile`의 `SPARKLE_ACCOUNT` 기본값은 `com.woosublee.Zap.sparkle.ed25519`를 유지한다. `check-eddsa-key`는 `generate_keys --account "$(SPARKLE_ACCOUNT)" -p` 출력이 `Info.plist`의 `SUPublicEDKey`와 일치하는지 검증하고, 같은 account의 공식 Sparkle Keychain 항목이 존재하는지 확인한다.

### Code signing identity

Release-oriented target의 기본 code signing identity는 `zap`으로 변경한다.

```make
RELEASE_CODESIGN_IDENTITY ?= zap
LOCAL_CERTIFICATE_IDENTITY ?= $(RELEASE_CODESIGN_IDENTITY)
```

`create-local-certificate`와 `check-local-certificate`의 흐름은 유지한다. 기존 `Zap Local` 인증서는 자동 삭제하지 않는다. 새 기본값인 `zap` 인증서가 필요하면 `make create-local-certificate`가 생성하거나 재사용한다.

### 업데이트 체크 주기

`Info.plist`에 `SUUpdateCheckInterval`을 추가하지 않는다. Sparkle 기본 자동 체크 주기인 하루 1회를 사용한다. Sparkle의 최소 체크 간격은 1시간이지만, Zap은 현재 별도의 짧은 체크 주기를 요구하지 않는다.

현재 동작은 유지한다.

- release tag 형식의 `ZapBuildTag`에서만 앱 시작 시 자동 updater를 시작한다.
- 로컬 빌드에서도 사용자가 `Check for Updates...`를 누르면 수동 체크는 실행한다.
- 자동 다운로드/설치는 켜지 않는다.

### 문서화

README의 Sparkle release flow를 다음 기준으로 정리한다.

- self-signed code signing identity 이름: `zap`
- Sparkle EdDSA Keychain 항목:
  - service: `https://sparkle-project.org`
  - account: `com.woosublee.Zap.sparkle.ed25519`
  - label: `Private key for signing Sparkle updates`
- Sparkle CLI에서는 label/service가 고정이고 account만 선택한다는 설명
- 자동 업데이트 체크 주기는 기본값인 하루 1회라는 설명

## 오류 처리

- `check-eddsa-key`에서 public key가 `Info.plist`와 다르면 실패한다.
- Sparkle 공식 Keychain 항목이 없으면 실패한다.
- `check-local-certificate`에서 `zap` identity로 probe 서명과 검증이 되지 않으면 실패한다.
- 중복 Keychain 항목 삭제는 명시적 사용자 승인 후에만 수행한다. 이번 세션에서는 public-key-account 중복 항목을 삭제했고, 유지 대상 account의 존재를 확인했다.

## 테스트와 검증

구현 후 다음을 실행한다.

```sh
swift test
make check-eddsa-key
make check-local-certificate
```

필요하면 release bundle 서명 검증까지 확인한다.

```sh
make prod-verify
```

## 구현 범위

1. `Makefile`의 `RELEASE_CODESIGN_IDENTITY` 기본값을 `zap`으로 변경한다.
2. `Makefile`의 Sparkle account 설정은 `com.woosublee.Zap.sparkle.ed25519` 기준으로 유지한다.
3. README의 Sparkle release flow 설명을 위 기준으로 업데이트한다.
4. 필요한 경우 테스트에서 Makefile 기본 identity와 Sparkle metadata 문구를 검증한다.
