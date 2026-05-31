PRODUCT_NAME ?= Zap
APP_NAME ?= Zap
BUNDLE_ID ?= com.woosublee.zap
VERSION ?= 0.1.1
BUILD_NUMBER ?= 2
BUILD_TAG ?= local-unknown
BUILD_DIR ?= /tmp/zap-bundles/default
CONFIGURATION ?= debug
CODESIGN_IDENTITY ?= -
RELEASE_CODESIGN_IDENTITY ?= zap
CODESIGN_OPTIONS ?=
LOCAL_CERTIFICATE_IDENTITY ?= $(RELEASE_CODESIGN_IDENTITY)
DIST_DIR ?= dist
SPARKLE_TOOLS_DIR ?= .sparkle-tools
SPARKLE_VERSION ?= 2.9.2
SPARKLE_TOOLS_ARCHIVE := $(SPARKLE_TOOLS_DIR)/Sparkle-$(SPARKLE_VERSION).tar.xz
SPARKLE_TOOLS_ROOT := $(SPARKLE_TOOLS_DIR)/Sparkle-$(SPARKLE_VERSION)
SPARKLE_TOOLS_STAMP := $(SPARKLE_TOOLS_ROOT)/.ready
SPARKLE_GENERATE_KEYS := $(SPARKLE_TOOLS_ROOT)/bin/generate_keys
SPARKLE_GENERATE_APPCAST := $(SPARKLE_TOOLS_ROOT)/bin/generate_appcast
SPARKLE_SIGN_UPDATE := $(SPARKLE_TOOLS_ROOT)/bin/sign_update
SPARKLE_ACCOUNT ?= com.woosublee.Zap.sparkle.ed25519
APPCAST_BASE_URL ?= https://woosublee.github.io/zap
DOWNLOAD_BASE_URL ?= https://github.com/woosublee/zap/releases/download/v$(VERSION)/
ICON_NAME ?= Zap
ICON_FILE ?= Resources/$(ICON_NAME).icns
MENU_BAR_ICON_FILE ?= Resources/ZapMenuBarIcon.png
DEV_APP_NAME ?= Zap dev
DEV_BUNDLE_ID ?= com.woosublee.zap.dev
DEV_BUILD_DIR ?= /tmp/zap-bundles/dev
PROD_APP_NAME ?= Zap
PROD_BUNDLE_ID ?= com.woosublee.zap
PROD_BUILD_DIR ?= /tmp/zap-bundles/prod

APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_BUNDLE)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
FRAMEWORKS_DIR := $(CONTENTS_DIR)/Frameworks
INFO_PLIST := Info.plist
ENTITLEMENTS := Zap.entitlements
RELEASE_ARCHIVE := $(DIST_DIR)/$(APP_NAME)-$(VERSION).zip

.PHONY: all swift-build bundle embed-sparkle sign verify run install install-and-run dev-build dev-verify dev-run prod-build prod-verify prod-run prod-install prod-install-and-run test clean distclean create-local-certificate check-local-certificate generate-eddsa-key check-eddsa-key require-release-build-tag release-archive appcast release

all: sign

swift-build:
	swift build -c $(CONFIGURATION) --product "$(PRODUCT_NAME)"

bundle: swift-build embed-sparkle $(INFO_PLIST) $(ENTITLEMENTS)
	build_dir="$$(swift build -c "$(CONFIGURATION)" --show-bin-path)"; \
	app_executable="$$build_dir/$(PRODUCT_NAME)"; \
	test -x "$$app_executable" || { echo "Missing executable: $$app_executable"; exit 1; }; \
	rm -rf "$(MACOS_DIR)" "$(RESOURCES_DIR)" "$(CONTENTS_DIR)/Info.plist"; \
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)" "$(FRAMEWORKS_DIR)"; \
	ditto --norsrc --noextattr "$$app_executable" "$(MACOS_DIR)/$(APP_NAME)"; \
	if ! otool -l "$(MACOS_DIR)/$(APP_NAME)" | grep -A2 LC_RPATH | grep -F "@executable_path/../Frameworks" >/dev/null; then \
		install_name_tool -add_rpath "@executable_path/../Frameworks" "$(MACOS_DIR)/$(APP_NAME)"; \
	fi
	cp "$(INFO_PLIST)" "$(CONTENTS_DIR)/Info.plist"
	plutil -replace CFBundleName -string "$(APP_NAME)" "$(CONTENTS_DIR)/Info.plist"
	plutil -replace CFBundleDisplayName -string "$(APP_NAME)" "$(CONTENTS_DIR)/Info.plist"
	plutil -replace CFBundleExecutable -string "$(APP_NAME)" "$(CONTENTS_DIR)/Info.plist"
	plutil -replace CFBundleIdentifier -string "$(BUNDLE_ID)" "$(CONTENTS_DIR)/Info.plist"
	plutil -replace CFBundleShortVersionString -string "$(VERSION)" "$(CONTENTS_DIR)/Info.plist"
	plutil -replace CFBundleVersion -string "$(BUILD_NUMBER)" "$(CONTENTS_DIR)/Info.plist"
	plutil -replace ZapBuildTag -string "$(BUILD_TAG)" "$(CONTENTS_DIR)/Info.plist"
	@if [ -f "$(ICON_FILE)" ]; then \
		ditto --norsrc --noextattr "$(ICON_FILE)" "$(RESOURCES_DIR)/$(ICON_NAME).icns"; \
		plutil -replace CFBundleIconFile -string "$(ICON_NAME)" "$(CONTENTS_DIR)/Info.plist"; \
	fi
	test -f "$(MENU_BAR_ICON_FILE)" || { echo "Missing menu bar icon: $(MENU_BAR_ICON_FILE)"; exit 1; }
	ditto --norsrc --noextattr "$(MENU_BAR_ICON_FILE)" "$(RESOURCES_DIR)/ZapMenuBarIcon.png"
	chmod +x "$(MACOS_DIR)/$(APP_NAME)"
	xattr -r -c "$(APP_BUNDLE)"
	@echo "Bundled $(APP_BUNDLE)"

embed-sparkle: swift-build
	@build_dir="$$(swift build -c "$(CONFIGURATION)" --show-bin-path)"; \
	framework="$$(find "$$build_dir" -name Sparkle.framework -type d -print -quit)"; \
	if [ -z "$$framework" ]; then \
		echo "Missing Sparkle.framework under $$build_dir"; \
		exit 1; \
	fi; \
	mkdir -p "$(FRAMEWORKS_DIR)"; \
	rm -rf "$(FRAMEWORKS_DIR)/Sparkle.framework"; \
	ditto --norsrc --noextattr "$$framework" "$(FRAMEWORKS_DIR)/Sparkle.framework"; \
	echo "Embedded $(FRAMEWORKS_DIR)/Sparkle.framework"

sign: bundle
	@if [ "$(CODESIGN_IDENTITY)" != "-" ]; then \
		for item in \
			"$(FRAMEWORKS_DIR)/Sparkle.framework/Versions/B/XPCServices/Installer.xpc" \
			"$(FRAMEWORKS_DIR)/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc" \
			"$(FRAMEWORKS_DIR)/Sparkle.framework/Versions/B/Autoupdate" \
			"$(FRAMEWORKS_DIR)/Sparkle.framework/Versions/B/Updater.app" \
			"$(FRAMEWORKS_DIR)/Sparkle.framework/XPCServices/Installer.xpc" \
			"$(FRAMEWORKS_DIR)/Sparkle.framework/XPCServices/Downloader.xpc" \
			"$(FRAMEWORKS_DIR)/Sparkle.framework/Autoupdate" \
			"$(FRAMEWORKS_DIR)/Sparkle.framework/Updater.app"; do \
			if [ -e "$$item" ]; then \
				codesign --force $(CODESIGN_OPTIONS) --sign "$(CODESIGN_IDENTITY)" "$$item"; \
			fi; \
		done; \
		codesign --force $(CODESIGN_OPTIONS) --sign "$(CODESIGN_IDENTITY)" "$(FRAMEWORKS_DIR)/Sparkle.framework"; \
		codesign --force $(CODESIGN_OPTIONS) --sign "$(CODESIGN_IDENTITY)" --entitlements "$(ENTITLEMENTS)" "$(APP_BUNDLE)"; \
	else \
		codesign --force --sign "-" --entitlements "$(ENTITLEMENTS)" "$(APP_BUNDLE)"; \
	fi
	xattr -r -c "$(APP_BUNDLE)"

verify: sign
	codesign --verify --strict --verbose=2 "$(APP_BUNDLE)"
	plutil -extract CFBundleIdentifier raw "$(APP_BUNDLE)/Contents/Info.plist" | grep -Fx "$(BUNDLE_ID)" >/dev/null
	plutil -extract CFBundleIconFile raw "$(APP_BUNDLE)/Contents/Info.plist" | grep -Fx "$(ICON_NAME)" >/dev/null
	plutil -extract ZapBuildTag raw "$(APP_BUNDLE)/Contents/Info.plist" | grep -Fx "$(BUILD_TAG)" >/dev/null
	test -f "$(RESOURCES_DIR)/$(ICON_NAME).icns"
	test -f "$(RESOURCES_DIR)/ZapMenuBarIcon.png"
	test -d "$(FRAMEWORKS_DIR)/Sparkle.framework"
	codesign --verify --strict --verbose=2 "$(FRAMEWORKS_DIR)/Sparkle.framework"
	otool -l "$(MACOS_DIR)/$(APP_NAME)" | grep -A2 LC_RPATH | grep -F "@executable_path/../Frameworks" >/dev/null
	@echo "verification passed"

create-local-certificate:
	@if security find-certificate -c "$(LOCAL_CERTIFICATE_IDENTITY)" >/dev/null; then \
		echo "Reusing existing code signing certificate: $(LOCAL_CERTIFICATE_IDENTITY)"; \
	else \
		tmpdir="$$(mktemp -d)"; \
		trap 'rm -rf "'"'$$tmpdir'"'"' EXIT; \
		printf '%s\n' \
			'[req]' \
			'distinguished_name = req_distinguished_name' \
			'x509_extensions = v3_req' \
			'prompt = no' \
			'[req_distinguished_name]' \
			'CN = $(LOCAL_CERTIFICATE_IDENTITY)' \
			'[v3_req]' \
			'basicConstraints = critical,CA:false' \
			'keyUsage = critical,digitalSignature' \
			'extendedKeyUsage = critical,codeSigning' \
			> "$$tmpdir/openssl.cnf"; \
		openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
			-keyout "$$tmpdir/$(LOCAL_CERTIFICATE_IDENTITY).key" \
			-out "$$tmpdir/$(LOCAL_CERTIFICATE_IDENTITY).crt" \
			-config "$$tmpdir/openssl.cnf"; \
		p12_password="zap-local-temporary-import-password"; \
		openssl pkcs12 -legacy -export -passout pass:$$p12_password \
			-inkey "$$tmpdir/$(LOCAL_CERTIFICATE_IDENTITY).key" \
			-in "$$tmpdir/$(LOCAL_CERTIFICATE_IDENTITY).crt" \
			-out "$$tmpdir/$(LOCAL_CERTIFICATE_IDENTITY).p12" \
			-name "$(LOCAL_CERTIFICATE_IDENTITY)"; \
		keychain="$$(security default-keychain | sed 's/^ *//; s/"//g')"; \
		security import "$$tmpdir/$(LOCAL_CERTIFICATE_IDENTITY).p12" -k "$$keychain" -P "$$p12_password" -T /usr/bin/codesign; \
		security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$$keychain" >/dev/null 2>&1 || true; \
	fi
	$(MAKE) check-local-certificate

check-local-certificate:
	@security find-certificate -c "$(LOCAL_CERTIFICATE_IDENTITY)" >/dev/null
	@tmpdir="$$(mktemp -d)"; \
	trap 'rm -rf "'"'$$tmpdir'"'"' EXIT; \
	probe="$$tmpdir/probe"; \
	printf '#!/bin/sh\nexit 0\n' > "$$probe"; \
	chmod +x "$$probe"; \
	codesign --force --sign "$(LOCAL_CERTIFICATE_IDENTITY)" "$$probe"; \
	codesign --verify --strict --verbose=2 "$$probe"; \
	echo "Code signing identity works: $(LOCAL_CERTIFICATE_IDENTITY)"

sparkle-tools: $(SPARKLE_TOOLS_STAMP)

$(SPARKLE_TOOLS_STAMP):
	mkdir -p "$(SPARKLE_TOOLS_DIR)"
	@if [ ! -f "$(SPARKLE_TOOLS_ARCHIVE)" ]; then \
		curl -L --fail -o "$(SPARKLE_TOOLS_ARCHIVE)" "https://github.com/sparkle-project/Sparkle/releases/download/$(SPARKLE_VERSION)/Sparkle-$(SPARKLE_VERSION).tar.xz"; \
	fi
	rm -rf "$(SPARKLE_TOOLS_ROOT)"
	mkdir -p "$(SPARKLE_TOOLS_ROOT)"
	tar -xJf "$(SPARKLE_TOOLS_ARCHIVE)" -C "$(SPARKLE_TOOLS_ROOT)" --strip-components 1
	test -x "$(SPARKLE_GENERATE_KEYS)"
	test -x "$(SPARKLE_GENERATE_APPCAST)"
	test -x "$(SPARKLE_SIGN_UPDATE)"
	touch "$(SPARKLE_TOOLS_STAMP)"

check-eddsa-key: $(SPARKLE_TOOLS_STAMP)
	@key="$$("$(SPARKLE_GENERATE_KEYS)" --account "$(SPARKLE_ACCOUNT)" -p)"; \
	plist_key="$$(plutil -extract SUPublicEDKey raw "$(INFO_PLIST)")"; \
	printf '%s\n' "$$key"; \
	if [ "$$key" != "$$plist_key" ]; then \
		echo "Sparkle EdDSA Keychain public key does not match $(INFO_PLIST) SUPublicEDKey"; \
		exit 1; \
	fi
	security find-generic-password -s "https://sparkle-project.org" -a "$(SPARKLE_ACCOUNT)" >/dev/null

generate-eddsa-key: $(SPARKLE_TOOLS_STAMP)
	"$(SPARKLE_GENERATE_KEYS)" --account "$(SPARKLE_ACCOUNT)"
	$(MAKE) check-eddsa-key

require-release-build-tag:
	@test "$(BUILD_TAG)" = "v$(VERSION)" || { \
		echo "Release builds require BUILD_TAG=v$(VERSION) (got $(BUILD_TAG))"; \
		exit 1; \
	}

release-archive: require-release-build-tag prod-verify
	rm -rf "$(DIST_DIR)"
	mkdir -p "$(DIST_DIR)"
	ditto -c -k --keepParent "$(PROD_BUILD_DIR)/$(PROD_APP_NAME).app" "$(RELEASE_ARCHIVE)"
	@echo "Created $(RELEASE_ARCHIVE)"

appcast: $(SPARKLE_TOOLS_STAMP) release-archive check-eddsa-key
	"$(SPARKLE_GENERATE_APPCAST)" --account "$(SPARKLE_ACCOUNT)" --download-url-prefix "$(DOWNLOAD_BASE_URL)" -o "$(DIST_DIR)/appcast.xml" "$(DIST_DIR)"
	python3 -c 'exec("\n".join(["from pathlib import Path", "import re", "import sys", "from xml.sax.saxutils import escape, unescape", "path = Path(sys.argv[1])", "text = path.read_text()", "item_pattern = re.compile(r\"(<item\\b[^>]*>)(.*?)(</item>)\", re.DOTALL)", "version_pattern = re.compile(r\"\\s*<sparkle:version>(.*?)</sparkle:version>\", re.DOTALL)", "enclosure_without_version_pattern = re.compile(r\"<enclosure\\b(?![^>]*\\bsparkle:version=)\")", "", "def transform_item(match):", "    start, body, end = match.groups()", "    versions = version_pattern.findall(body)", "    if not versions:", "        return match.group(0)", "    version = escape(unescape(versions[0].strip()), dict([(\"\\\"\", \"&quot;\")]))", "    body = version_pattern.sub(\"\", body)", "    if \"sparkle:version=\" not in body:", "        body, count = enclosure_without_version_pattern.subn(f\"<enclosure sparkle:version=\\\"{version}\\\"\", body, count=1)", "        if count != 1:", "            raise SystemExit(\"Missing enclosure for sparkle:version\")", "    return f\"{start}{body}{end}\"", "", "text = item_pattern.sub(transform_item, text)", "path.write_text(text)"]))' "$(DIST_DIR)/appcast.xml"
	@echo "Created $(DIST_DIR)/appcast.xml"

release: create-local-certificate generate-eddsa-key appcast
	@echo "Release archive: $(RELEASE_ARCHIVE)"
	@echo "Appcast: $(DIST_DIR)/appcast.xml"
	@echo "Appcast base URL: $(APPCAST_BASE_URL)"

dev-build:
	$(MAKE) sign APP_NAME="$(DEV_APP_NAME)" BUNDLE_ID="$(DEV_BUNDLE_ID)" BUILD_DIR="$(DEV_BUILD_DIR)" CODESIGN_IDENTITY="-"

dev-verify:
	$(MAKE) verify APP_NAME="$(DEV_APP_NAME)" BUNDLE_ID="$(DEV_BUNDLE_ID)" BUILD_DIR="$(DEV_BUILD_DIR)" CODESIGN_IDENTITY="-"

dev-run:
	$(MAKE) run APP_NAME="$(DEV_APP_NAME)" BUNDLE_ID="$(DEV_BUNDLE_ID)" BUILD_DIR="$(DEV_BUILD_DIR)" CODESIGN_IDENTITY="-"

prod-build:
	$(MAKE) sign APP_NAME="$(PROD_APP_NAME)" BUNDLE_ID="$(PROD_BUNDLE_ID)" BUILD_DIR="$(PROD_BUILD_DIR)" CONFIGURATION=release CODESIGN_IDENTITY="$(RELEASE_CODESIGN_IDENTITY)" CODESIGN_OPTIONS="$(CODESIGN_OPTIONS)"

prod-verify:
	$(MAKE) verify APP_NAME="$(PROD_APP_NAME)" BUNDLE_ID="$(PROD_BUNDLE_ID)" BUILD_DIR="$(PROD_BUILD_DIR)" CONFIGURATION=release CODESIGN_IDENTITY="$(RELEASE_CODESIGN_IDENTITY)" CODESIGN_OPTIONS="$(CODESIGN_OPTIONS)"

prod-run:
	$(MAKE) run APP_NAME="$(PROD_APP_NAME)" BUNDLE_ID="$(PROD_BUNDLE_ID)" BUILD_DIR="$(PROD_BUILD_DIR)" CONFIGURATION=release CODESIGN_IDENTITY="$(RELEASE_CODESIGN_IDENTITY)" CODESIGN_OPTIONS="$(CODESIGN_OPTIONS)"

prod-install:
	$(MAKE) install APP_NAME="$(PROD_APP_NAME)" BUNDLE_ID="$(PROD_BUNDLE_ID)" BUILD_DIR="$(PROD_BUILD_DIR)" CONFIGURATION=release CODESIGN_IDENTITY="$(RELEASE_CODESIGN_IDENTITY)" CODESIGN_OPTIONS="$(CODESIGN_OPTIONS)"

prod-install-and-run:
	$(MAKE) install-and-run APP_NAME="$(PROD_APP_NAME)" BUNDLE_ID="$(PROD_BUNDLE_ID)" BUILD_DIR="$(PROD_BUILD_DIR)" CONFIGURATION=release CODESIGN_IDENTITY="$(RELEASE_CODESIGN_IDENTITY)" CODESIGN_OPTIONS="$(CODESIGN_OPTIONS)"

run: sign
	open "$(APP_BUNDLE)"

install: sign
	mkdir -p "/Applications/$(APP_NAME).app"
	ditto --norsrc --noextattr "$(APP_BUNDLE)" "/Applications/$(APP_NAME).app"
	@echo "Installed /Applications/$(APP_NAME).app"

install-and-run: install
	-pkill -x "$(APP_NAME)"
	open "/Applications/$(APP_NAME).app"

test:
	swift test

clean:
	rm -rf "$(BUILD_DIR)"

distclean: clean
	rm -rf .build
