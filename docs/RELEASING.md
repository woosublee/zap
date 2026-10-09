# Zap 릴리스

**한국어** | [English](RELEASING.en.md)

자동 업데이트용 릴리스는 GitHub Actions의 **Notarized Release** 워크플로가 빌드하고, GitHub Release 첨부 파일로 올립니다. 앱은 아래 Sparkle 피드를 확인합니다.

```text
https://github.com/woosublee/zap/releases/latest/download/appcast.xml
```

릴리스는 hardened runtime과 보안 타임스탬프를 켠 상태로 `Developer ID Application: Woosub Lee (2L6ZW98RCP)` 인증서로 서명합니다. 앱을 공증·staple한 뒤 패키징하고, 이어서 DMG도 서명·공증·staple한 다음 Gatekeeper 검사를 거칩니다. `appcast.xml`의 Sparkle EdDSA 서명은 staple이 끝난 DMG로 마지막에 만듭니다.

Zap 0.1.11 이하는 자체 서명한 `zap` 인증서로 서명했습니다. EdDSA 키(`Info.plist`의 `SUPublicEDKey`)가 그대로라서 Sparkle은 서명 인증서가 바뀐 것을 받아들이고, 해당 버전 사용자도 정상적으로 업데이트됩니다. 다만 macOS는 손쉬운 사용 권한을 서명 인증서에 묶어 두기 때문에, 기존 사용자는 이 업데이트 후 손쉬운 사용 권한을 한 번 다시 허용해야 합니다. Sparkle 키와 서명 인증서를 같은 릴리스에서 함께 바꾸면 안 됩니다.

릴리스 워크플로에는 다음 GitHub Secrets가 필요합니다.

- `DEVELOPER_ID_CERTIFICATE_BASE64`: Developer ID Application 인증서와 개인 키가 든 `.p12`를 base64로 인코딩한 값
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`: 위 `.p12`의 비밀번호
- `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`: `notarytool`이 쓰는 App Store Connect API 키
- `SPARKLE_PRIVATE_KEY`: `appcast.xml` 서명용 Sparkle EdDSA 개인 키

커밋된 Sparkle 공개 키는 `Info.plist`의 `SUPublicEDKey`에 있습니다. 개인 키, `.p12`, `.p8`은 절대 커밋하지 마세요.

Sparkle 개인 키는 정해진 키체인 항목을 사용합니다.

```zsh
make generate-eddsa-key
make check-eddsa-key
```

Sparkle 개인 키를 이미 파일로 갖고 있다면, 새 공개 키를 만들지 말고 정해진 키체인 항목에 복사하세요.

```zsh
security add-generic-password \
  -U \
  -s "https://sparkle-project.org" \
  -a "com.woosublee.Zap.sparkle.ed25519" \
  -l "Private key for signing Sparkle updates" \
  -D "private key" \
  -j "Public key (SUPublicEDKey value) for this key is:\n\n$(plutil -extract SUPublicEDKey raw Info.plist)" \
  -w "$(cat build/sparkle_private_key.txt)"
```

키체인 접근에서 Developer ID Application 인증서를 `.p12`로 내보낸 다음, 로컬에서 GitHub Secrets를 등록합니다.

```zsh
DEVELOPER_ID_CERTIFICATE_P12=/path/to/developer-id.p12 \
DEVELOPER_ID_CERTIFICATE_PASSWORD=... \
ASC_ISSUER_ID=... \
scripts/register-release-secrets.sh
```

이 스크립트는 `.p12`와 Sparkle 개인 키를 검증하고, `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`에서 API 키를 읽습니다(`ASC_KEY_PATH`, `ASC_KEY_ID`로 바꿀 수 있음). 그다음 `gh secret set`으로 시크릿을 등록하고, 더 이상 쓰지 않는 `ZAP_CERTIFICATE_BASE64`, `ZAP_CERTIFICATE_PASSWORD` 시크릿을 지웁니다. 시크릿 값은 출력하지 않습니다.

워크플로를 실행하기 전에 `Info.plist`와 `Makefile` 양쪽의 버전과 빌드 번호를 올리세요. `make -s print-app-version`, `make -s print-build-number`, `make -s print-build-tag`, 워크플로에 입력한 태그가 서로 다르면 워크플로가 릴리스를 거부합니다.

`v1.2.3` 같은 새 태그를 입력해서 **Notarized Release** 워크플로를 실행하세요. 태그를 미리 만들면 안 됩니다. 워크플로가 원격에 같은 태그가 없는지 확인하고, 워크플로 커밋으로 빌드하고, 앱과 DMG를 서명·공증하고, `dist/appcast.xml`을 만든 뒤, 태그를 생성하고 다음 두 파일을 릴리스에 올립니다.

- `Zap-<version>.dmg`
- `appcast.xml`

## 로컬 대체 릴리스

로컬 대체 릴리스에는 로컬 키체인의 Developer ID Application 인증서와 `notarytool` 키체인 프로필(기본값 `woosublee-notary`, `NOTARY_PROFILE`로 변경 가능)이 필요합니다.

```zsh
security find-identity -v -p codesigning | grep "Developer ID Application"
xcrun notarytool store-credentials woosublee-notary --key <AuthKey.p8> --key-id <ASC_KEY_ID> --issuer <ASC_ISSUER_ID>
```

대체 스크립트는 `v*` 태그와 서명·공증 자격 증명을 검증하고, `Makefile`에서 버전 정보를 읽은 뒤 DMG를 빌드·서명·공증·검증합니다. 이어서 키체인의 Sparkle 개인 키로 `dist/appcast.xml`을 만들고, 인증된 `gh` CLI로 두 파일을 릴리스에 올립니다.

```zsh
scripts/release-local.sh v1.2.3
```

기본적으로 대체 스크립트는 이미 올라간 GitHub Release 파일을 덮어쓰지 않습니다. 기존 릴리스의 DMG와 appcast를 의도적으로 교체할 때만 `ALLOW_LOCAL_RELEASE_CLOBBER=1`을 설정하세요.
