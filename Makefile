APP_NAME ?= Snap
BUNDLE_ID ?= com.woosublee.snap
VERSION ?= 0.1.0
BUILD_NUMBER ?= 1
BUILD_DIR ?= build
CONFIGURATION ?= debug
CODESIGN_IDENTITY ?= -
ICON_NAME ?= Snap
ICON_FILE ?= Resources/$(ICON_NAME).icns
MENU_BAR_ICON_FILE ?= Resources/SnapMenuBarIcon.png

APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_BUNDLE)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
SWIFT_BUILD_DIR = $(shell swift build -c $(CONFIGURATION) --show-bin-path)
APP_EXECUTABLE = $(SWIFT_BUILD_DIR)/$(APP_NAME)
INFO_PLIST := Info.plist
ENTITLEMENTS := Snap.entitlements

.PHONY: all swift-build bundle sign verify run install install-and-run test clean distclean

all: sign

swift-build:
	swift build -c $(CONFIGURATION) --product $(APP_NAME)

bundle: swift-build $(INFO_PLIST) $(ENTITLEMENTS)
	test -x "$(APP_EXECUTABLE)" || { echo "Missing executable: $(APP_EXECUTABLE)"; exit 1; }
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	ditto --norsrc --noextattr "$(APP_EXECUTABLE)" "$(MACOS_DIR)/$(APP_NAME)"
	cp "$(INFO_PLIST)" "$(CONTENTS_DIR)/Info.plist"
	plutil -replace CFBundleName -string "$(APP_NAME)" "$(CONTENTS_DIR)/Info.plist"
	plutil -replace CFBundleDisplayName -string "$(APP_NAME)" "$(CONTENTS_DIR)/Info.plist"
	plutil -replace CFBundleExecutable -string "$(APP_NAME)" "$(CONTENTS_DIR)/Info.plist"
	plutil -replace CFBundleIdentifier -string "$(BUNDLE_ID)" "$(CONTENTS_DIR)/Info.plist"
	plutil -replace CFBundleShortVersionString -string "$(VERSION)" "$(CONTENTS_DIR)/Info.plist"
	plutil -replace CFBundleVersion -string "$(BUILD_NUMBER)" "$(CONTENTS_DIR)/Info.plist"
	@if [ -f "$(ICON_FILE)" ]; then \
		ditto --norsrc --noextattr "$(ICON_FILE)" "$(RESOURCES_DIR)/$(ICON_NAME).icns"; \
		plutil -replace CFBundleIconFile -string "$(ICON_NAME)" "$(CONTENTS_DIR)/Info.plist"; \
	fi
	@if [ -f "$(MENU_BAR_ICON_FILE)" ]; then \
		ditto --norsrc --noextattr "$(MENU_BAR_ICON_FILE)" "$(RESOURCES_DIR)/SnapMenuBarIcon.png"; \
	fi
	chmod +x "$(MACOS_DIR)/$(APP_NAME)"
	xattr -r -c "$(APP_BUNDLE)"
	@echo "Bundled $(APP_BUNDLE)"

sign: bundle
	codesign --force --options runtime --sign "$(CODESIGN_IDENTITY)" --entitlements "$(ENTITLEMENTS)" "$(APP_BUNDLE)"
	xattr -r -c "$(APP_BUNDLE)"

verify: sign
	codesign --verify --deep --strict --verbose=2 "$(APP_BUNDLE)"
	plutil -extract CFBundleIdentifier raw "$(APP_BUNDLE)/Contents/Info.plist" | grep -Fx "$(BUNDLE_ID)" >/dev/null
	plutil -extract CFBundleIconFile raw "$(APP_BUNDLE)/Contents/Info.plist" | grep -Fx "$(ICON_NAME)" >/dev/null
	test -f "$(RESOURCES_DIR)/$(ICON_NAME).icns"
	test -f "$(RESOURCES_DIR)/SnapMenuBarIcon.png"
	@echo "verification passed"

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
