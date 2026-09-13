APP_NAME = MinaFlow
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app
CONTENTS_DIR = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

FRAMEWORKS_DIR = $(CONTENTS_DIR)/Frameworks

# Include local developer credentials if present (ignored by Git, keeps private credentials off GitHub)
-include local.mk

# Code signing identity (defaults to ad-hoc '-' for local development and open-source builds)
# For official distribution: make release IDENTITY="Developer ID Application: ..."
IDENTITY ?= -
NOTARY_PROFILE ?= minaflow-notary
ENTITLEMENTS = Resources/MinaFlow.entitlements

.PHONY: all build run kill clean dmg notarize release

all: build

build:
	@echo "Compiling MinaFlow with Swift..."
	swift build -c release
	@echo "Creating macOS App Bundle..."
	@mkdir -p $(MACOS_DIR)
	@mkdir -p $(RESOURCES_DIR)
	@mkdir -p $(FRAMEWORKS_DIR)
	@cp $(BUILD_DIR)/MinaType $(MACOS_DIR)/$(APP_NAME)
	@cp Resources/Info.plist $(CONTENTS_DIR)/Info.plist
	@if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns $(RESOURCES_DIR)/AppIcon.icns; fi
	@if [ -f Resources/MenuBarIcon.png ]; then cp Resources/MenuBarIcon.png $(RESOURCES_DIR)/MenuBarIcon.png; fi
	@if [ -f Resources/AppLogo.png ]; then cp Resources/AppLogo.png $(RESOURCES_DIR)/AppLogo.png; fi
	@if [ -d Resources/bin ]; then \
		cp -R Resources/bin $(RESOURCES_DIR)/; \
		chmod +x $(RESOURCES_DIR)/bin/*; \
		codesign --force --options runtime --sign "$(IDENTITY)" $(RESOURCES_DIR)/bin/whisper-cli 2>/dev/null || true; \
	fi
	@echo "Embedding Sparkle Framework..."
	@if [ -d .build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework ]; then \
		rm -rf $(FRAMEWORKS_DIR)/Sparkle.framework; \
		cp -R .build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework $(FRAMEWORKS_DIR)/; \
	elif [ -d $(BUILD_DIR)/Sparkle.framework ]; then \
		rm -rf $(FRAMEWORKS_DIR)/Sparkle.framework; \
		cp -R $(BUILD_DIR)/Sparkle.framework $(FRAMEWORKS_DIR)/; \
	fi
	@echo "Configuring Frameworks runtime search path..."
	@install_name_tool -add_rpath @executable_path/../Frameworks $(MACOS_DIR)/$(APP_NAME) 2>/dev/null || true
	@echo "Signing Sparkle Framework & App Bundle with Developer ID and Hardened Runtime..."
	@if [ -d $(FRAMEWORKS_DIR)/Sparkle.framework ]; then \
		codesign --force --deep --options runtime --sign "$(IDENTITY)" $(FRAMEWORKS_DIR)/Sparkle.framework; \
	fi
	@codesign --force --options runtime --entitlements $(ENTITLEMENTS) --sign "$(IDENTITY)" $(APP_BUNDLE)
	@echo "Built and signed $(APP_BUNDLE) successfully!"

run: build kill
	@echo "Launching MinaFlow..."
	@open $(APP_BUNDLE)
	@echo "MinaFlow is now running in your Mac Menu Bar."

kill:
	@-pkill -f "MinaFlow.app/Contents/MacOS/MinaFlow" 2>/dev/null || true
	@-pkill -x MinaFlow 2>/dev/null || true
	@-pkill -f "MinaType" 2>/dev/null || true

dmg: build
	@echo "Creating MinaFlow.dmg with Applications drag-and-drop link..."
	@rm -rf .dmg-staging MinaFlow.dmg website/public/MinaFlow.dmg website/dist/MinaFlow.dmg
	@python3 scripts/generate_clean_dmg_bg.py
	@mkdir -p .dmg-staging
	@cp -R $(APP_BUNDLE) .dmg-staging/
	@if command -v create-dmg >/dev/null 2>&1; then \
		create-dmg \
			--volname "MinaFlow" \
			--background "Resources/dmg-background.png" \
			--window-pos 200 120 \
			--window-size 660 400 \
			--icon-size 120 \
			--icon "$(APP_NAME).app" 180 190 \
			--hide-extension "$(APP_NAME).app" \
			--app-drop-link 480 190 \
			--overwrite \
			MinaFlow.dmg \
			.dmg-staging || { \
				rm -rf .dmg-staging; \
				mkdir -p .dmg-staging; \
				cp -R $(APP_BUNDLE) .dmg-staging/; \
				ln -s /Applications .dmg-staging/Applications; \
				hdiutil create -volname "MinaFlow" -srcfolder .dmg-staging -ov -format UDZO MinaFlow.dmg; \
			}; \
	else \
		ln -s /Applications .dmg-staging/Applications; \
		hdiutil create -volname "MinaFlow" -srcfolder .dmg-staging -ov -format UDZO MinaFlow.dmg; \
	fi
	@rm -rf .dmg-staging
	@echo "Signing MinaFlow.dmg with Developer ID..."
	@codesign --force --sign "$(IDENTITY)" MinaFlow.dmg
	@cp MinaFlow.dmg website/public/MinaFlow.dmg
	@cp MinaFlow.dmg website/dist/MinaFlow.dmg 2>/dev/null || true
	@echo "Created signed MinaFlow.dmg!"

notarize:
	@echo "Submitting MinaFlow.dmg to Apple Notary Service..."
	xcrun notarytool submit MinaFlow.dmg --keychain-profile "$(NOTARY_PROFILE)" --wait
	@echo "Stapling notarization ticket to MinaFlow.dmg..."
	xcrun stapler staple MinaFlow.dmg
	@echo "Stapling notarization ticket to $(APP_BUNDLE)..."
	xcrun stapler staple $(APP_BUNDLE)
	@echo "Verifying Gatekeeper acceptance..."
	spctl -a -t open --context context:primary-signature -v MinaFlow.dmg
	spctl -a -t exec -v $(APP_BUNDLE)
	@cp MinaFlow.dmg website/public/MinaFlow.dmg
	@cp MinaFlow.dmg website/dist/MinaFlow.dmg 2>/dev/null || true
	@echo "Notarization and Stapling complete! Distributed to website/public/MinaFlow.dmg."

release: dmg notarize

clean:
	@rm -rf .build $(APP_BUNDLE) MinaFlow.dmg
