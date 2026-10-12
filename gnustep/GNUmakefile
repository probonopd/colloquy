#  GNUmakefile
#
#  Copyright (c) 2026 Simon Peter
#
#  SPDX-License-Identifier: BSD-2-Clause
#
#  Headless tests for the ported Colloquy Chat Core.  Both tools link the
#  library built by ../ChatCoreLib, so they must be compiled with exactly the
#  same port configuration as that subproject.

PACKAGE_NAME = chatcore-tests

include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = test_smoke test_join

# Keep everything in the SYSTEM domain; never install to LOCAL.
GNUSTEP_INSTALLATION_DOMAIN = SYSTEM

PORTS = -DGNUSTEP=1 \
        -DENABLE_IRC=1 -DENABLE_ICB=0 -DENABLE_SILC=0 -DENABLE_XMPP=0 \
        -DENABLE_PLUGINS=0 -DENABLE_SCRIPTING=0 -DENABLE_AUTO_PORT_MAPPING=0 \
        -DUSE_ATTRIBUTED_CHAT_STRING=1 -DCOMMAND_LINE_UTILITY=1 \
        -DNS_BLOCK_ASSERTIONS=1

test_smoke_OBJC_FILES = test_smoke.m
test_join_OBJC_FILES = test_join.m

ADDITIONAL_CPPFLAGS += $(PORTS) -I$(CURDIR)/.. -I$(CURDIR) -I$(CURDIR)/../ChatCore \
	-I$(CURDIR)/../Additions -include CQCompatibility.h

# Prefer the freshly built library over any installed copy.
ADDITIONAL_LIB_DIRS = -L$(CURDIR)/../ChatCoreLib/obj

# -lgnustep-gui: the chat-format conversion goes through NSFontManager.
test_smoke_TOOL_LIBS = -lchatcore -lgnustep-gui
test_join_TOOL_LIBS = -lchatcore -lgnustep-gui

include $(GNUSTEP_MAKEFILES)/tool.make
