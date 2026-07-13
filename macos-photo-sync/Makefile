# ------------------------------------------------------------------------
# Photo Library Sync — build a distributable macOS .app with plain swiftc.
# No Xcode project required (Xcode command-line tools are enough).
#
#   make            build a native .app for this Mac's architecture
#   make universal  build a universal (arm64 + x86_64) .app that runs on
#                   both Apple Silicon and Intel Macs
#   make run        build, then launch the app
#   make clean      remove the build output
# ------------------------------------------------------------------------

APP_NAME   := PhotoLibrarySync
BUNDLE_ID  := com.example.photolibrarysync
BUILD_DIR  := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS   := $(APP_BUNDLE)/Contents
MACOS_DIR  := $(CONTENTS)/MacOS
RES_DIR    := $(CONTENTS)/Resources
BIN        := $(MACOS_DIR)/$(APP_NAME)

SOURCES    := $(wildcard Sources/*.swift)
DEPLOY_TGT := 12.0

FRAMEWORKS := -framework SwiftUI -framework AppKit -framework Photos \
              -framework CoreGraphics -framework ImageIO -framework CryptoKit \
              -framework UniformTypeIdentifiers -framework Foundation

SWIFTFLAGS := -O

.PHONY: all universal run clean

all: bundle
	swiftc $(SWIFTFLAGS) -target $$(uname -m)-apple-macosx$(DEPLOY_TGT) \
		$(SOURCES) $(FRAMEWORKS) -o $(BIN)
	@$(MAKE) --no-print-directory sign
	@echo "Built $(APP_BUNDLE) (native)"

universal: bundle
	swiftc $(SWIFTFLAGS) -target arm64-apple-macosx$(DEPLOY_TGT) \
		$(SOURCES) $(FRAMEWORKS) -o $(BUILD_DIR)/$(APP_NAME)-arm64
	swiftc $(SWIFTFLAGS) -target x86_64-apple-macosx$(DEPLOY_TGT) \
		$(SOURCES) $(FRAMEWORKS) -o $(BUILD_DIR)/$(APP_NAME)-x86_64
	lipo -create -output $(BIN) \
		$(BUILD_DIR)/$(APP_NAME)-arm64 $(BUILD_DIR)/$(APP_NAME)-x86_64
	@rm -f $(BUILD_DIR)/$(APP_NAME)-arm64 $(BUILD_DIR)/$(APP_NAME)-x86_64
	@$(MAKE) --no-print-directory sign
	@echo "Built $(APP_BUNDLE) (universal: arm64 + x86_64)"

# Assemble the .app skeleton and copy Info.plist in.
bundle:
	@mkdir -p $(MACOS_DIR) $(RES_DIR)
	@cp Info.plist $(CONTENTS)/Info.plist

# Ad-hoc code signature. Required for the Photos-access (TCC) prompt to
# appear and for the app to launch. No paid Developer ID needed.
sign:
	@codesign --force --deep --sign - --options runtime $(APP_BUNDLE) \
		2>/dev/null || codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "Ad-hoc signed."

run: all
	open $(APP_BUNDLE)

clean:
	rm -rf $(BUILD_DIR)
