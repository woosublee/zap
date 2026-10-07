PRODUCT_NAME ?= Zap
APP_NAME ?= Zap
BUNDLE_ID ?= com.woosublee.zap
VERSION ?= 0.1.12
BUILD_NUMBER ?= 13
BUILD_TAG ?= local-unknown
BUILD_DIR ?= /tmp/zap-bundles/default
CONFIGURATION ?= debug
CODESIGN_IDENTITY ?= Developer ID Application: Woosub Lee (2L6ZW98RCP)
RELEASE_CODESIGN_IDENTITY ?= $(CODESIGN_IDENTITY)
CODESIGN_OPTIONS ?=
RELEASE_CODESIGN_OPTIONS ?= --options runtime --timestamp
NOTARY_PROFILE ?= woosublee-notary
NOTARY_KEYCHAIN ?=
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
REPOSITORY ?= woosublee/zap
DOWNLOAD_BASE_URL ?= https://github.com/$(REPOSITORY)/releases/download/v$(VERSION)/
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
PERMISSION_FLOW_BUNDLE := PermissionFlow_PermissionFlow.bundle
FRAMEWORKS_DIR := $(CONTENTS_DIR)/Frameworks
INFO_PLIST := Info.plist
ENTITLEMENTS := Zap.entitlements
RELEASE_ARCHIVE := $(DIST_DIR)/$(APP_NAME)-$(VERSION).zip
RELEASE_DMG := $(DIST_DIR)/$(APP_NAME)-$(VERSION).dmg
PROD_APP_BUNDLE := $(PROD_BUILD_DIR)/$(PROD_APP_NAME).app

.PHONY: all print-app-version print-build-number print-build-tag swift-build bundle embed-sparkle sign verify run install install-and-run dev-build dev-verify dev-run prod-build prod-verify prod-run prod-install prod-install-and-run test clean distclean check-codesign-identity generate-eddsa-key check-eddsa-key require-release-build-tag notarize-app release-archive release-dmg verify-dmg sign-dmg notarize-dmg verify-notarized-dmg prepare-release-dmg appcast release

all: sign

print-app-version:
	@printf '%s\n' "$(VERSION)"

print-build-number:
	@printf '%s\n' "$(BUILD_NUMBER)"

print-build-tag:
	@printf 'v%s\n' "$(VERSION)"

swift-build:
	swift build -c $(CONFIGURATION) --product "$(PRODUCT_NAME)"

bundle: swift-build $(INFO_PLIST) $(ENTITLEMENTS)
	build_dir="$$(swift build -c "$(CONFIGURATION)" --show-bin-path)"; \
	app_executable="$$build_dir/$(PRODUCT_NAME)"; \
	test -x "$$app_executable" || { echo "Missing executable: $$app_executable"; exit 1; }; \
	rm -rf "$(APP_BUNDLE)"; \
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)" "$(FRAMEWORKS_DIR)"; \
	$(MAKE) embed-sparkle CONFIGURATION="$(CONFIGURATION)" BUILD_DIR="$(BUILD_DIR)"; \
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
	build_dir="$$(swift build -c "$(CONFIGURATION)" --show-bin-path)"; \
	test -d "$$build_dir/$(PERMISSION_FLOW_BUNDLE)" || { echo "Missing $(PERMISSION_FLOW_BUNDLE) under $$build_dir"; exit 1; }; \
	rm -rf "$(RESOURCES_DIR)/$(PERMISSION_FLOW_BUNDLE)"; \
	ditto --norsrc --noextattr "$$build_dir/$(PERMISSION_FLOW_BUNDLE)" "$(RESOURCES_DIR)/$(PERMISSION_FLOW_BUNDLE)"
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
	@for item in \
		"$(FRAMEWORKS_DIR)/Sparkle.framework/Versions/B/XPCServices/Installer.xpc" \
		"$(FRAMEWORKS_DIR)/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc" \
		"$(FRAMEWORKS_DIR)/Sparkle.framework/Versions/B/Autoupdate" \
		"$(FRAMEWORKS_DIR)/Sparkle.framework/Versions/B/Updater.app" \
		"$(FRAMEWORKS_DIR)/Sparkle.framework/XPCServices/Installer.xpc" \
		"$(FRAMEWORKS_DIR)/Sparkle.framework/XPCServices/Downloader.xpc" \
		"$(FRAMEWORKS_DIR)/Sparkle.framework/Autoupdate" \
		"$(FRAMEWORKS_DIR)/Sparkle.framework/Updater.app"; do \
		if [ -e "$$item" ]; then \
			codesign --force $(CODESIGN_OPTIONS) --preserve-metadata=entitlements --sign "$(CODESIGN_IDENTITY)" "$$item"; \
		fi; \
	done
	codesign --force $(CODESIGN_OPTIONS) --sign "$(CODESIGN_IDENTITY)" "$(FRAMEWORKS_DIR)/Sparkle.framework"
	codesign --force $(CODESIGN_OPTIONS) --sign "$(CODESIGN_IDENTITY)" --entitlements "$(ENTITLEMENTS)" "$(APP_BUNDLE)"
	xattr -r -c "$(APP_BUNDLE)"

verify: sign
	codesign --verify --strict --verbose=2 "$(APP_BUNDLE)"
	plutil -extract CFBundleIdentifier raw "$(APP_BUNDLE)/Contents/Info.plist" | grep -Fx "$(BUNDLE_ID)" >/dev/null
	plutil -extract CFBundleIconFile raw "$(APP_BUNDLE)/Contents/Info.plist" | grep -Fx "$(ICON_NAME)" >/dev/null
	plutil -extract ZapBuildTag raw "$(APP_BUNDLE)/Contents/Info.plist" | grep -Fx "$(BUILD_TAG)" >/dev/null
	test -f "$(RESOURCES_DIR)/$(ICON_NAME).icns"
	test -f "$(RESOURCES_DIR)/ZapMenuBarIcon.png"
	test -d "$(RESOURCES_DIR)/$(PERMISSION_FLOW_BUNDLE)"
	test -d "$(FRAMEWORKS_DIR)/Sparkle.framework"
	codesign --verify --strict --verbose=2 "$(FRAMEWORKS_DIR)/Sparkle.framework"
	otool -l "$(MACOS_DIR)/$(APP_NAME)" | grep -A2 LC_RPATH | grep -F "@executable_path/../Frameworks" >/dev/null
	@echo "verification passed"

check-codesign-identity:
	@security find-identity -v -p codesigning | grep -F -- "$(RELEASE_CODESIGN_IDENTITY)" >/dev/null || { \
		echo "Missing code signing identity: $(RELEASE_CODESIGN_IDENTITY)"; \
		exit 1; \
	}
	@echo "Code signing identity found: $(RELEASE_CODESIGN_IDENTITY)"

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

# Notarizes the signed production app and staples the ticket so the DMG and
# Sparkle updates carry an app that passes Gatekeeper offline.
notarize-app:
	test -d "$(PROD_APP_BUNDLE)" || { echo "Missing app: $(PROD_APP_BUNDLE)"; exit 1; }
	@tmpdir="$$(mktemp -d)"; \
	trap 'rm -rf "$$tmpdir"' EXIT; \
	ditto -c -k --keepParent "$(PROD_APP_BUNDLE)" "$$tmpdir/$(PROD_APP_NAME)-notarize.zip"; \
	NOTARY_PROFILE="$(NOTARY_PROFILE)" NOTARY_KEYCHAIN="$(NOTARY_KEYCHAIN)" scripts/notarize.sh "$$tmpdir/$(PROD_APP_NAME)-notarize.zip"
	xcrun stapler staple "$(PROD_APP_BUNDLE)"
	xcrun stapler validate "$(PROD_APP_BUNDLE)"

release-archive: require-release-build-tag prod-verify
	rm -rf "$(DIST_DIR)"
	mkdir -p "$(DIST_DIR)"
	$(MAKE) notarize-app
	ditto -c -k --keepParent "$(PROD_APP_BUNDLE)" "$(RELEASE_ARCHIVE)"
	@echo "Created $(RELEASE_ARCHIVE)"

release-dmg: release-archive
	mkdir -p "$(DIST_DIR)"
	rm -f "$(RELEASE_DMG)"
	hdiutil create -volname "$(APP_NAME) $(VERSION)" -srcfolder "$(PROD_APP_BUNDLE)" -ov -format UDZO "$(RELEASE_DMG)"
	hdiutil verify "$(RELEASE_DMG)"
	@echo "Created $(RELEASE_DMG)"

verify-dmg:
	test -f "$(RELEASE_DMG)"
	APP_NAME="$(PROD_APP_NAME)" scripts/verify-dmg.sh "$(RELEASE_DMG)"

verify-notarized-dmg:
	test -f "$(RELEASE_DMG)"
	VERIFY_GATEKEEPER=1 APP_NAME="$(PROD_APP_NAME)" scripts/verify-dmg.sh "$(RELEASE_DMG)"

sign-dmg:
	test -f "$(RELEASE_DMG)" || { echo "Missing DMG: $(RELEASE_DMG)"; exit 1; }
	codesign --force --timestamp --sign "$(CODESIGN_IDENTITY)" "$(RELEASE_DMG)"
	@echo "Signed $(RELEASE_DMG)"

notarize-dmg:
	test -f "$(RELEASE_DMG)" || { echo "Missing DMG: $(RELEASE_DMG)"; exit 1; }
	NOTARY_PROFILE="$(NOTARY_PROFILE)" NOTARY_KEYCHAIN="$(NOTARY_KEYCHAIN)" scripts/notarize.sh "$(RELEASE_DMG)"
	xcrun stapler staple "$(RELEASE_DMG)"
	xcrun stapler validate "$(RELEASE_DMG)"
	@echo "Notarized $(RELEASE_DMG)"

# Sparkle signs the DMG bytes, so the appcast must be generated after stapling.
prepare-release-dmg: release-dmg
	$(MAKE) verify-dmg
	$(MAKE) sign-dmg CODESIGN_IDENTITY="$(RELEASE_CODESIGN_IDENTITY)"
	$(MAKE) notarize-dmg
	$(MAKE) verify-notarized-dmg

appcast: prepare-release-dmg check-eddsa-key $(SPARKLE_TOOLS_STAMP)
	RELEASE_TAG="v$(VERSION)" VERSION="$(VERSION)" BUILD_NUMBER="$(BUILD_NUMBER)" DMG_PATH="$(RELEASE_DMG)" APPCAST_PATH="$(DIST_DIR)/appcast.xml" REPOSITORY="$(REPOSITORY)" SPARKLE_SIGN_UPDATE="$(SPARKLE_SIGN_UPDATE)" scripts/generate-sparkle-appcast.sh
	@echo "Created $(DIST_DIR)/appcast.xml"

release: check-codesign-identity appcast
	@echo "Release archive: $(RELEASE_ARCHIVE)"
	@echo "Release DMG: $(RELEASE_DMG)"
	@echo "Appcast: $(DIST_DIR)/appcast.xml"
	@echo "Publish $(RELEASE_DMG) and $(DIST_DIR)/appcast.xml as GitHub Release assets."

dev-build:
	$(MAKE) sign APP_NAME="$(DEV_APP_NAME)" BUNDLE_ID="$(DEV_BUNDLE_ID)" BUILD_DIR="$(DEV_BUILD_DIR)"

dev-verify:
	$(MAKE) verify APP_NAME="$(DEV_APP_NAME)" BUNDLE_ID="$(DEV_BUNDLE_ID)" BUILD_DIR="$(DEV_BUILD_DIR)"

dev-run:
	$(MAKE) run APP_NAME="$(DEV_APP_NAME)" BUNDLE_ID="$(DEV_BUNDLE_ID)" BUILD_DIR="$(DEV_BUILD_DIR)"

prod-build:
	$(MAKE) sign APP_NAME="$(PROD_APP_NAME)" BUNDLE_ID="$(PROD_BUNDLE_ID)" BUILD_DIR="$(PROD_BUILD_DIR)" CONFIGURATION=release CODESIGN_IDENTITY="$(RELEASE_CODESIGN_IDENTITY)" CODESIGN_OPTIONS="$(RELEASE_CODESIGN_OPTIONS)"

prod-verify:
	$(MAKE) verify APP_NAME="$(PROD_APP_NAME)" BUNDLE_ID="$(PROD_BUNDLE_ID)" BUILD_DIR="$(PROD_BUILD_DIR)" CONFIGURATION=release CODESIGN_IDENTITY="$(RELEASE_CODESIGN_IDENTITY)" CODESIGN_OPTIONS="$(RELEASE_CODESIGN_OPTIONS)"

prod-run:
	$(MAKE) run APP_NAME="$(PROD_APP_NAME)" BUNDLE_ID="$(PROD_BUNDLE_ID)" BUILD_DIR="$(PROD_BUILD_DIR)" CONFIGURATION=release CODESIGN_IDENTITY="$(RELEASE_CODESIGN_IDENTITY)" CODESIGN_OPTIONS="$(RELEASE_CODESIGN_OPTIONS)"

prod-install:
	$(MAKE) install APP_NAME="$(PROD_APP_NAME)" BUNDLE_ID="$(PROD_BUNDLE_ID)" BUILD_DIR="$(PROD_BUILD_DIR)" CONFIGURATION=release CODESIGN_IDENTITY="$(RELEASE_CODESIGN_IDENTITY)" CODESIGN_OPTIONS="$(RELEASE_CODESIGN_OPTIONS)"

prod-install-and-run:
	$(MAKE) install-and-run APP_NAME="$(PROD_APP_NAME)" BUNDLE_ID="$(PROD_BUNDLE_ID)" BUILD_DIR="$(PROD_BUILD_DIR)" CONFIGURATION=release CODESIGN_IDENTITY="$(RELEASE_CODESIGN_IDENTITY)" CODESIGN_OPTIONS="$(RELEASE_CODESIGN_OPTIONS)"

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
