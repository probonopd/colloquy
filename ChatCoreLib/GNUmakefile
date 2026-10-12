#  GNUmakefile
#
#  Copyright (c) 2026 Simon Peter
#
#  SPDX-License-Identifier: BSD-2-Clause
#
#  GNUstep build for the Colloquy Chat Core library (IRC protocol subset).

PACKAGE_NAME = colloquy-chatcore

include $(GNUSTEP_MAKEFILES)/common.make

LIBRARY_NAME = chatcore

# Keep everything in the SYSTEM domain; never install to LOCAL.
GNUSTEP_INSTALLATION_DOMAIN = SYSTEM

# Port configuration: IRC only, attributed chat strings (as on macOS), no plugins/scripting/SILC/XMPP.
PORTS = -DGNUSTEP=1 \
        -DENABLE_IRC=1 -DENABLE_ICB=0 -DENABLE_SILC=0 -DENABLE_XMPP=0 \
        -DENABLE_PLUGINS=0 -DENABLE_SCRIPTING=0 -DENABLE_AUTO_PORT_MAPPING=0 \
        -DENABLE_REACHABILITY=0 \
        -DUSE_ATTRIBUTED_CHAT_STRING=1 -DCOMMAND_LINE_UTILITY=1 \
        -DNS_BLOCK_ASSERTIONS=1

# Force the GNUstep compatibility header into every compilation unit so that
# the source files need no further @import/module rewrites.
ADDITIONAL_CPPFLAGS += $(PORTS) -I$(CURDIR)/../gnustep -I$(CURDIR)/../ChatCore -I$(CURDIR)/../Additions -include CQCompatibility.h

# ChatCore is a symlink to "Chat Core" (avoids spaces in GNUstep make paths).
chatcore_OBJC_FILES = \
	../gnustep/CQSerialQueue.m \
	../gnustep/CQAsyncSocket.m \
	../ChatCore/ICBPacket.m \
	../ChatCore/MVChatConnection.m \
	../ChatCore/MVChatPluginManager.m \
	../ChatCore/MVChatRoom.m \
	../ChatCore/MVChatUser.m \
	../ChatCore/MVChatUserWatchRule.m \
	../ChatCore/MVDirectChatConnection.m \
	../ChatCore/MVDirectClientConnection.m \
	../ChatCore/MVFileTransfer.m \
	../ChatCore/MVIRCChatConnection.m \
	../ChatCore/MVIRCChatRoom.m \
	../ChatCore/MVIRCChatUser.m \
	../ChatCore/MVIRCFileTransfer.m \
	../Additions/NSAttributedStringAdditions.m \
	../Additions/NSStringAdditions.m \
	../Additions/NSDataAdditions.m \
	../Additions/NSDateAdditions.m \
	../Additions/NSFileManagerAdditions.m \
	../Additions/NSMethodSignatureAdditions.m \
	../Additions/NSNotificationAdditions.m \
	../Additions/NSNumberAdditions.m \
	../Additions/NSRegularExpressionAdditions.m \
	../Additions/NSScannerAdditions.m

chatcore_LIBRARIES_DEPEND_UPON = $(FND_LIBS) $(OBJC_LIBS) -lgnustep-gui

# Match the upstream Xcode build: Chat Core is ARC (only ICB used -fno-objc-arc,
# and ICB is disabled in this port).
ADDITIONAL_OBJCFLAGS = -fobjc-arc -Wno-unused-but-set-variable -Wno-objc-designated-initializers

include $(GNUSTEP_MAKEFILES)/library.make
