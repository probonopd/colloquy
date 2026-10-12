#  GNUmakefile
#
#  Copyright (c) 2026 Simon Peter
#
#  SPDX-License-Identifier: BSD-2-Clause
#
#  GNUstep build for Colloquy (the 2.x GUI port) with the Chat Core
#  library built as a subproject.

PACKAGE_NAME = colloquy

include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = Colloquy

# Chat Core is built first as a subproject; the app links against it.
Colloquy_SUBPROJECTS = ChatCoreLib

# Port configuration: IRC only, attributed chat strings (as on macOS), no
# plugins/scripting.  Assertions are compiled out as in every configuration of
# the Xcode project (Settings/Base.xcconfig); the sources rely on that, e.g.
# JVStyle's -dealloc passes nil to a method that asserts a non-nil argument.
# libxml2 and libxslt live under /usr on Linux and under /usr/local on the
# BSDs, so ask their own config scripts where they are instead of hardcoding.
XML2_CONFIG := $(shell command -v xml2-config)
ifeq ($(XML2_CONFIG),)
$(error xml2-config not found; install the libxml2 development files)
endif
XSLT_CONFIG := $(shell command -v xslt-config)
ifeq ($(XSLT_CONFIG),)
$(error xslt-config not found; install the libxslt development files)
endif

PORTS = -DGNUSTEP=1 \
        -DENABLE_IRC=1 -DENABLE_ICB=0 -DENABLE_SILC=0 -DENABLE_XMPP=0 \
        -DENABLE_PLUGINS=0 -DENABLE_SCRIPTING=0 -DENABLE_AUTO_PORT_MAPPING=0 \
        -DENABLE_REACHABILITY=0 \
        -DUSE_ATTRIBUTED_CHAT_STRING=1 -DCOMMAND_LINE_UTILITY=1 \
        -DNS_BLOCK_ASSERTIONS=1

# Chat Core sources include CQCompatibility.h themselves under #ifdef GNUSTEP.
# The app sources get the app-level GSCompatibility.h injected instead.
ADDITIONAL_CPPFLAGS += $(PORTS) \
	-I$(CURDIR) \
	-I$(CURDIR)/gnustep \
	-I$(CURDIR)/gnustep-app \
	-I$(CURDIR)/Additions \
	-I$(CURDIR)/ChatCore \
	-I$(CURDIR)/Mac-Old/Mac-Old/Views \
	-I$(CURDIR)/Mac-Old/Mac-Old/Controllers \
	-I$(CURDIR)/Mac-Old/Mac-Old/Models \
	-I$(CURDIR)/Mac-Old/Mac-Old/Panels \
	-I$(CURDIR)/Mac-Old/Mac-Old/Inspectors \
	-I$(CURDIR)/Mac-Old/Mac-Old/Preferences \
	-I$(CURDIR)/Mac-Old/Mac-Old/Plug-Ins/SDK \
	-I$(CURDIR)/Shared/Controllers \
	-I$(CURDIR)/Shared/Models \
	$(shell $(XML2_CONFIG) --cflags) \
	$(shell $(XSLT_CONFIG) --cflags) \
	-include GSCompatibility.h

# GNUstep's AppKit declares the NSOutlineView data source and delegate, the
# menu delegate and parts of the toolbar delegate as @required where Cocoa has
# them @optional, so every class that adopts one is reported as incomplete and
# every delegate method implemented in a category is reported as overriding the
# primary class.  Neither says anything about this code.
#
# The application target is ARC, as it is in the Xcode project: most of these
# sources were written for it and free nothing in -dealloc, so building them
# without ARC leaks every object they own.  The handful of files that predate
# ARC are listed below and keep manual retain/release.
ADDITIONAL_OBJCFLAGS = -fobjc-arc -fobjc-exceptions -D_NATIVE_OBJC_EXCEPTIONS \
	-Wno-deprecated-declarations -Wno-unused-but-set-variable \
	-Wno-objc-designated-initializers \
	-Wno-protocol -Wno-objc-protocol-method-implementation \
	-Wno-arc-performSelector-leaks

# Sources that are not part of an ARC target upstream: the GNUstep framework
# shims, the views and controllers that no Xcode target builds any more, and
# the Standard Commands plug-in (CLANG_ENABLE_OBJC_ARC = NO).
Colloquy_MRR_FILES = \
	gnustep-app/GSCompatibility.m \
	gnustep-app/WebKit/WebView.m \
	Mac-Old/Mac-Old/Controllers/CQActivityWindowController.m \
	Mac-Old/Mac-Old/Panels/JVChatTranscriptBrowserPanel.m \
	Mac-Old/Mac-Old/Views/CQButtonCell.m \
	Mac-Old/Mac-Old/Views/CQDownloadCell.m \
	Mac-Old/Mac-Old/Views/CQGroupCell.m \
	Mac-Old/Mac-Old/Views/CQOutlineView.m \
	Mac-Old/Mac-Old/Views/CQSubtitleCell.m \
	Mac-Old/Mac-Old/Views/CQTitleCell.m \
	Mac-Old/Mac-Old/Views/KABubbleWindow.m \
	Mac-Old/Mac-Old/Views/MVImageTextCell.m \
	Mac-Old/StandardCommands/JVStandardCommands.m

$(foreach f,$(Colloquy_MRR_FILES),$(eval $(f)_FILE_FLAGS = -fno-objc-arc))

# The Additions categories Chat Core also uses (NSStringAdditions and friends)
# are not listed here: they are compiled into libchatcore, and building them a
# second time would install every category twice, in a different
# memory-management mode than the copy the library already provides.
Colloquy_OBJC_FILES = \
	gnustep-app/GSCompatibility.m \
	gnustep-app/JVStyleView.m \
	gnustep-app/WebKit/WebView.m \
	gnustep-app/MASPreferences/MASPreferences.m \
	Mac-Old/Mac-Old/main.m \
	Mac-Old/Mac-Old/Controllers/CQActivityWindowController.m \
	Mac-Old/Mac-Old/Controllers/JVAnalyticsController.m \
	Mac-Old/Mac-Old/Controllers/JVChatController.m \
	Mac-Old/Mac-Old/Controllers/JVChatRoomBrowser.m \
	Mac-Old/Mac-Old/Controllers/JVChatViewCriterionController.m \
	Mac-Old/Mac-Old/Controllers/JVChatWindowController.m \
	Mac-Old/Mac-Old/Controllers/JVInspectorController.m \
	Mac-Old/Mac-Old/Controllers/JVNotificationController.m \
	Mac-Old/Mac-Old/Controllers/JVSidebarChatWindowController.m \
	Mac-Old/Mac-Old/Controllers/JVSpeechController.m \
	Mac-Old/Mac-Old/Controllers/JVTabbedChatWindowController.m \
	Mac-Old/Mac-Old/Controllers/JVTranscriptCriterionController.m \
	Mac-Old/Mac-Old/Controllers/JVTranscriptFindWindowController.m \
	Mac-Old/Mac-Old/Controllers/KABubbleWindowController.m \
	Mac-Old/Mac-Old/Controllers/MVApplicationController.m \
	Mac-Old/Mac-Old/Controllers/MVBuddyListController.m \
	Mac-Old/Mac-Old/Controllers/MVConnectionsController.m \
	Mac-Old/Mac-Old/Controllers/MVCrashCatcher.m \
	Mac-Old/Mac-Old/Controllers/MVFileTransferController.m \
	Mac-Old/Mac-Old/Controllers/PFMoveApplicationController.m \
	Mac-Old/Mac-Old/Models/JVBuddy.m \
	Mac-Old/Mac-Old/Models/JVChatEvent.m \
	Mac-Old/Mac-Old/Models/JVChatMessage.m \
	Mac-Old/Mac-Old/Models/JVChatSession.m \
	Mac-Old/Mac-Old/Models/JVChatTranscript.m \
	Mac-Old/Mac-Old/Models/JVEmoticonSet.m \
	Mac-Old/Mac-Old/Models/JVStyle.m \
	Mac-Old/Mac-Old/Models/MVKeyChain.m \
	Mac-Old/Mac-Old/Panels/JVChatConsolePanel.m \
	Mac-Old/Mac-Old/Panels/JVChatRoomMember.m \
	Mac-Old/Mac-Old/Panels/JVChatRoomPanel.m \
	Mac-Old/Mac-Old/Panels/JVChatTabItem.m \
	Mac-Old/Mac-Old/Panels/JVChatTranscriptBrowserPanel.m \
	Mac-Old/Mac-Old/Panels/JVChatTranscriptPanel.m \
	Mac-Old/Mac-Old/Panels/JVDirectChatPanel.m \
	Mac-Old/Mac-Old/Panels/JVSmartTranscriptPanel.m \
	Mac-Old/Mac-Old/Panels/MVChatUserAdditions.m \
	Mac-Old/Mac-Old/Views/AICustomTabCell.m \
	Mac-Old/Mac-Old/Views/AICustomTabDragWindow.m \
	Mac-Old/Mac-Old/Views/AICustomTabDragging.m \
	Mac-Old/Mac-Old/Views/AICustomTabsView.m \
	Mac-Old/Mac-Old/Views/CQButtonCell.m \
	Mac-Old/Mac-Old/Views/CQDownloadCell.m \
	Mac-Old/Mac-Old/Views/CQGroupCell.m \
	Mac-Old/Mac-Old/Views/CQOutlineView.m \
	Mac-Old/Mac-Old/Views/CQSubtitleCell.m \
	Mac-Old/Mac-Old/Views/CQTitleCell.m \
	Mac-Old/Mac-Old/Views/ESFloater.m \
	Mac-Old/Mac-Old/Views/JVColorWellCell.m \
	Mac-Old/Mac-Old/Views/JVDetailCell.m \
	Mac-Old/Mac-Old/Views/JVFontPreviewField.m \
	Mac-Old/Mac-Old/Views/JVMarkedScroller.m \
	Mac-Old/Mac-Old/Views/JVMixedTableColumn.m \
	Mac-Old/Mac-Old/Views/JVSideOutlineView.m \
	Mac-Old/Mac-Old/Views/JVSideSplitView.m \
	Mac-Old/Mac-Old/Views/JVSplitView.m \
	Mac-Old/Mac-Old/Views/JVToolbarItem.m \
	Mac-Old/Mac-Old/Views/JVViewCell.m \
	Mac-Old/Mac-Old/Views/KABubbleWindow.m \
	Mac-Old/Mac-Old/Views/KABubbleWindowView.m \
	Mac-Old/Mac-Old/Views/MVColorPanel.m \
	Mac-Old/Mac-Old/Views/MVImageTextCell.m \
	Mac-Old/Mac-Old/Views/MVMenuButton.m \
	Mac-Old/Mac-Old/Views/MVTableView.m \
	Mac-Old/Mac-Old/Views/MVTextView.m \
	Mac-Old/Mac-Old/Inspectors/JVBuddyInspector.m \
	Mac-Old/Mac-Old/Inspectors/JVChatRoomInspector.m \
	Mac-Old/Mac-Old/Inspectors/JVChatUserInspector.m \
	Mac-Old/Mac-Old/Inspectors/JVConnectionInspector.m \
	Mac-Old/Mac-Old/Preferences/CQMPreferencesWindowController.m \
	Mac-Old/Mac-Old/Preferences/JVAppearancePreferencesViewController.m \
	Mac-Old/Mac-Old/Preferences/JVBehaviorPreferencesViewController.m \
	Mac-Old/Mac-Old/Preferences/JVFileTransferPreferencesViewController.m \
	Mac-Old/Mac-Old/Preferences/JVGeneralPreferencesViewController.m \
	Mac-Old/Mac-Old/Preferences/JVInterfacePreferencesViewController.m \
	Mac-Old/Mac-Old/Preferences/JVNotificationPreferencesViewController.m \
	Mac-Old/Mac-Old/Preferences/JVTranscriptPreferencesViewController.m \
	Additions/NSAttributedStringMoreAdditions.m \
	Additions/NSBundleAdditions.m \
	Additions/NSCharacterSetAdditions.m \
	Additions/NSColorAdditions.m \
	Additions/NSDictionaryAdditions.m \
	Additions/NSFileManagerMoreAdditions.m \
	Additions/NSImageAdditions.m \
	Additions/NSObjectAdditions.m \
	Additions/NSScriptCommandAdditions.m \
	Additions/NSTextStorageAdditions.m \
	Additions/NSURLSessionAdditions.m \
	Additions/NSWindow+CQMCoordinateSpaceConversion.m \
	Shared/Controllers/CQKeychain.m \
	Shared/Models/KAIgnoreRule.m \
	Mac-Old/StandardCommands/JVStandardCommands.m

# The app links against the Chat Core library (IRC-only), libxml2 for the
# transcript model and styles, and the standard GNUstep GUI libraries.
Colloquy_OBJC_LIBS = -lchatcore $(shell $(XSLT_CONFIG) --libs) -lexslt \
	$(shell $(XML2_CONFIG) --libs) \
	$(FND_LIBS) $(OBJC_LIBS) -lgnustep-gui

# Keep everything in the SYSTEM domain; never install to LOCAL.
GNUSTEP_INSTALLATION_DOMAIN = SYSTEM

# The subproject's build directory has to be searched before anything else:
# gnustep-make puts the system library directory at the front of the link line,
# so -lchatcore would otherwise resolve to a previously installed Chat Core
# rather than the one just built.  LDFLAGS are emitted ahead of those -L flags.
#
# Chat Core is installed into the domain library directory like any other
# GNUstep library and found there at run time.  Carrying a second copy inside
# the bundle would achieve nothing: GNUstep.sh puts the domain library
# directories on LD_LIBRARY_PATH, which the loader consults before any
# RUNPATH, so the bundled copy could never win.
Colloquy_LDFLAGS = -L$(CURDIR)/ChatCoreLib/obj

# ---- Resources --------------------------------------------------------------
# The upstream Xcode project puts the main nib, panels and preferences nibs
# under Mac-Old/Mac-Old/Interfaces and Mac-Old/Mac-Old/Preferences.  Stage the
# resources into the bundle with a custom rule so the layout matches what the
# nib loading code expects (Resources/English.lproj for localized files).

Colloquy_APPLICATION_ICON = Colloquy.png

include $(GNUSTEP_MAKEFILES)/application.make

# Rules must follow the application.make include: the first explicit target
# in a makefile becomes make's default goal, so defining them earlier would
# make a bare "make" run only that rule instead of building the app.

# The nibs are generated from the xibs with "make nibs" and committed, because
# generating them needs gormtool and an X server, which a machine that only
# builds the application does not have.  A nib older than its xib no longer
# matches the interface, so the build refuses to package it.
XIBS = $(wildcard Mac-Old/Mac-Old/Interfaces/*.xib) \
       $(wildcard Mac-Old/Mac-Old/Interfaces/Languages/*/*.xib) \
       $(wildcard Mac-Old/Mac-Old/Preferences/Base.lproj/*.xib)

# The images the application looks up by name are rendered from the asset
# catalogue, the loose PDFs and gnustep/Images; like the nibs they are
# committed, and their sources are fingerprinted so a checkout builds.
# One of the directories has a space in its name, so the list is built and
# checksummed by the shell rather than passed through make.
IMAGE_STAMP_CMD = find Mac-Old/Mac-Old/Resources/Mac-Old.xcassets \
	"Mac-Old/Mac-Old/Resources/Misc Images" gnustep/Images \
	\( -name '*.pdf' -o -name '*.png' -o -name '*.eps' \) | \
	while read f; do cksum "$$f"; done | LC_ALL=C sort

.PHONY: images
images:
	python3 $(CURDIR)/gnustep/images.py
	@$(IMAGE_STAMP_CMD) > gnustep/image-stamps

.PHONY: nibs
nibs:
	python3 $(CURDIR)/gnustep/xib2nib.py $(XIBS)
	@cksum $(XIBS) | LC_ALL=C sort > gnustep/nib-stamps

before-all::
	@missing=$$(for x in $(XIBS); do \
		[ -f "$${x%.xib}.nib/keyedobjects.nib" ] || echo "$$x"; \
	done); \
	if [ -n "$$missing" ]; then \
		echo "These nibs are missing; regenerate them with"; \
		echo "  make nibs"; \
		echo "$$missing"; \
		exit 1; \
	fi
	# A checkout gives every file the same timestamp, so the nibs are compared
	# with the checksums the conversion recorded rather than with mtimes.
	@cksum $(XIBS) | LC_ALL=C sort > gnustep/nib-stamps.now; \
	if ! cmp -s gnustep/nib-stamps gnustep/nib-stamps.now; then \
		echo "These xibs changed after their nib was generated; regenerate with"; \
		echo "  make nibs"; \
		diff gnustep/nib-stamps gnustep/nib-stamps.now | grep '^>' | awk '{print $$4}'; \
		rm -f gnustep/nib-stamps.now; \
		exit 1; \
	fi; \
	rm -f gnustep/nib-stamps.now
	@$(IMAGE_STAMP_CMD) > gnustep/image-stamps.now; \
	if ! cmp -s gnustep/image-stamps gnustep/image-stamps.now; then \
		echo "These images changed after gnustep-app/Images was generated; regenerate with"; \
		echo "  make images"; \
		diff gnustep/image-stamps gnustep/image-stamps.now | grep '^>' | awk '{print $$4}'; \
		rm -f gnustep/image-stamps.now; \
		exit 1; \
	fi; \
	rm -f gnustep/image-stamps.now

after-all::
	# The bundle mirrors the Colloquy (Application) target: shared resources at
	# the top of Resources, localized ones in <language>.lproj, where GNUstep
	# calls the development language English.lproj.
	rm -rf $(CURDIR)/Colloquy.app/Resources/*.lproj $(CURDIR)/Colloquy.app/Resources/Styles \
		$(CURDIR)/Colloquy.app/Resources/Emoticons $(CURDIR)/Colloquy.app/Resources/Sounds
	$(MKDIRS) $(CURDIR)/Colloquy.app/Resources/English.lproj

	# Interfaces.  The localized nibs go into their language; the unlocalized
	# ones and the preference panes (a Base localization whose per-language
	# .strings GNUstep nibs cannot use) into English.lproj, which GNUstep
	# falls back to for every language.
	cp -R Mac-Old/Mac-Old/Interfaces/Languages/en.lproj/*.nib \
		Mac-Old/Mac-Old/Interfaces/*.nib \
		Mac-Old/Mac-Old/Preferences/Base.lproj/*.nib \
		$(CURDIR)/Colloquy.app/Resources/English.lproj/
	cp Resources/Languages/en.lproj/Localizable.strings \
		Resources/Languages/en.lproj/Credits.rtf \
		$(CURDIR)/Colloquy.app/Resources/English.lproj/
	set -e; for d in Mac-Old/Mac-Old/Interfaces/Languages/*.lproj; do \
		l=$$(basename $$d); \
		[ "$$l" = en.lproj ] && continue; \
		$(MKDIRS) $(CURDIR)/Colloquy.app/Resources/$$l; \
		cp -R $$d/*.nib $(CURDIR)/Colloquy.app/Resources/$$l/; \
		if [ -f $$d/InfoPlist.strings ]; then cp $$d/InfoPlist.strings $(CURDIR)/Colloquy.app/Resources/$$l/; fi; \
	done
	set -e; for d in Resources/Languages/*.lproj; do \
		l=$$(basename $$d); \
		[ "$$l" = en.lproj ] && continue; \
		$(MKDIRS) $(CURDIR)/Colloquy.app/Resources/$$l; \
		cp $$d/* $(CURDIR)/Colloquy.app/Resources/$$l/; \
	done

	# Chat styles, emoticon sets and sounds are looked up as folders directly
	# in Resources; the style support files sit beside them.
	cp -R "Mac-Old/Mac-Old/Resources/Style Support/Styles" \
		Mac-Old/Mac-Old/Resources/Emoticons \
		Resources/Sounds \
		$(CURDIR)/Colloquy.app/Resources/
	# The styles and emoticon sets are macOS bundles (Contents/Info.plist,
	# Contents/Resources), a layout GNUstep's NSBundle does not read: it would
	# find neither their identifiers nor their resources.  Lay them out the
	# GNUstep way, with the Info.plist among the resources.
	set -e; for b in $(CURDIR)/Colloquy.app/Resources/Styles/*.colloquyStyle \
			$(CURDIR)/Colloquy.app/Resources/Emoticons/*.colloquyEmoticons; do \
		mv "$$b/Contents/Resources" "$$b/Resources"; \
		mv "$$b/Contents/Info.plist" "$$b/Resources/Info-gnustep.plist"; \
		rmdir "$$b/Contents"; \
	done
	cd "Mac-Old/Mac-Old/Resources/Style Support" && cp base.html default.css default.js default.xsl \
		roomTopicBanner.html styleOptions.plist template.html $(CURDIR)/Colloquy.app/Resources/

	# Images, rendered by gnustep/images.py from the asset catalog and the PDF
	# images, and the bitmaps that need no conversion.
	cp gnustep-app/Images/*.png "Mac-Old/Mac-Old/Resources/Misc Images/"*.png \
		$(CURDIR)/Colloquy.app/Resources/
	cp Mac-Old/Mac-Old/Resources/Mac-Old.xcassets/AppIcon-Release.appiconset/Colloquy.png \
		$(CURDIR)/Colloquy.app/Resources/

	# Defaults, colour list, command verbs and the other plain resources.
	cp Mac-Old/Mac-Old/Resources/info.colloquy.plist \
		Mac-Old/Mac-Old/Resources/emoticons.plist \
		Mac-Old/Mac-Old/Resources/notifications.plist \
		Mac-Old/Mac-Old/Resources/preview.colloquyTranscript \
		Mac-Old/Mac-Old/Resources/GPL.txt \
		Mac-Old/Mac-Old/Resources/Generic.icns \
		Resources/Chat.clr/Chat.clr \
		Resources/verbs.plist \
		Resources/transcriptSchema.sql \
		$(CURDIR)/Colloquy.app/Resources/

	# Some source nibs ship with restrictive permissions; if those reach the
	# installed bundle the app (running as a normal user) cannot read them and
	# every nib load fails with "Data passed to nib loading method is nil".
	# Always leave the staged bundle world-readable.
	chmod -R u+rwX,go+rX $(CURDIR)/Colloquy.app
