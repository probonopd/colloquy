/*
 * CFString.h
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Minimal CoreFoundation shim for GNUstep.  CQCompatibility.h, which is force
 * included into every Chat Core and application source file, already defines
 * the CFString types, CFSTR() and the ISO-Latin encoding constants that are
 * used, so this header only has to exist so that sources importing the macOS
 * CoreFoundation headers directly still compile.
 */

#ifndef GS_CFSTRING_H
#define GS_CFSTRING_H

#import <Foundation/Foundation.h>

// CQCompatibility.h already provides the CFString surface; nothing to add.

#endif