#!/usr/bin/env python3
#
# Copyright (c) 2026 Simon Peter
#
# SPDX-License-Identifier: BSD-2-Clause
#
"""Generate GNUstep nibs from Colloquy's Interface Builder xibs.

GNUstep cannot use the xibs directly, so each one is converted with gormtool.
gormtool's output is not usable as it comes, and every defect below leaves a
window that loads but does not work; they are all repaired from the xib the
nib was generated from:

  * WebView elements, and search fields with an empty recents autosave name,
    make the conversion fail outright.  Colloquy's WebViews are JVStyleView
    instances, which on GNUstep is a plain NSView subclass, so they are
    converted as custom views; the empty autosave name is dropped.
  * Connection endpoints are unreliable: every endpoint that refers to a
    placeholder (File's Owner, First Responder, Application) is written as
    nil, so controller outlets stay nil and buttons have no target; a window
    used as an endpoint is replaced by a copy outside the object graph that
    steals the real window's content view when instantiated; some action
    connectors lose their control.  Every outlet and action connector is
    rewritten from the xib, with First Responder left nil so that actions
    travel the responder chain.
  * Custom classes on views, cells and table columns are dropped, so for
    example MVMenuButton buttons show no menu and NSSecureTextField echoes
    passwords.  Objects get their xib class back when that class exists in
    the application or in GNUstep.
  * Cocoa bindings are dropped entirely, and shared user defaults controllers
    lose representsSharedInstance, so preference controls neither show nor
    store their settings.  The binding connectors and the flag are restored.
  * Every table column carries an empty list of prototype cell views, which
    makes GNUstep treat all tables as view-based and draw none of their cells.
    The empty lists are removed.
  * The localized xibs turn off subview autoresizing on window content views,
    unlike the development-language ones, so self-resizing panels lose their
    controls.  Content views are made to autoresize their subviews again.
  * Every window is marked visible at launch.  Only windows the xib marks
    visibleAtLaunch stay so.
  * A stand-alone menu in an xib without a main menu is named MainMenu, so
    loading the nib installs it as the application's main menu, which takes
    its menu view away from the pop-up buttons using it.  The name is dropped
    unless the xib really has a main menu.

Usage:
  xib2nib.py [--gormtool PATH] xib [xib ...]

Each nib is written next to its xib.  gormtool is an AppKit program and needs
an X server; it produces incomplete nibs when a window manager is running on
it, so the tool starts a private Xvfb for the conversions.  Any conversion or
repair that cannot be completed is reported and makes the tool exit non-zero.
"""

import glob
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE_ROOT = os.path.dirname(HERE)


# ---- keyed archive helpers ------------------------------------------------

def uid(value):
	if isinstance(value, plistlib.UID):
		return value.data
	if isinstance(value, dict) and "CF$UID" in value:
		return value["CF$UID"]
	return None


class Archive:
	def __init__(self, path):
		with open(path, "rb") as f:
			self.data = plistlib.load(f)
		self.objects = self.data["$objects"]
		self.root = self.objects[1]
		self._classes = {}

	def save(self, path):
		with open(path, "wb") as f:
			plistlib.dump(self.data, f, fmt=plistlib.FMT_BINARY)

	def obj(self, index):
		if isinstance(index, int) and index > 0 and isinstance(self.objects[index], dict):
			return self.objects[index]
		return None

	def class_name(self, index):
		o = self.obj(index)
		if o is None:
			return None
		c = uid(o.get("$class"))
		return self.objects[c].get("$classname") if isinstance(c, int) else None

	def class_chain(self, index):
		c = uid(self.obj(index).get("$class"))
		return list(self.objects[c].get("$classes", []))

	def string(self, index):
		if isinstance(index, int) and isinstance(self.objects[index], str):
			return self.objects[index]
		return None

	def ref(self, index, key):
		o = self.obj(index)
		return uid(o.get(key)) if o is not None else None

	def array(self, index):
		o = self.obj(index)
		return [uid(x) for x in o.get("NS.objects", [])] if o is not None else []

	def add(self, value):
		self.objects.append(value)
		return len(self.objects) - 1

	def add_string(self, text):
		return self.add(text)

	def class_ref(self, name, chain):
		if name not in self._classes:
			self._classes[name] = self.add({"$classname": name, "$classes": chain})
		return self._classes[name]

	def root_ref(self, key):
		return uid(self.root.get(key))


# ---- xib <-> nib object correspondence --------------------------------------

# Where a keyed child element of an xib object is archived in the nib.
KEYED_CHILDREN = {
	("window", "contentView"): "NSWindowView",
	("scrollView", "contentView"): "NSContentView",
	("box", "contentView"): "NSContentView",
	("scrollView", "horizontalScroller"): "NSHScroller",
	("scrollView", "verticalScroller"): "NSVScroller",
}
KEYED_ANY_PARENT = {
	"cell": "NSCell",
	"dataCell": "NSDataCell",
	"headerCell": "NSHeaderCell",
	"submenu": "NSSubmenu",
	"menu": "NSMenu",
	"view": "NSView",
}
LISTS = {
	"subviews": "NSSubviews",
	"tableColumns": "NSTableColumns",
	"tabViewItems": "NSTabViewItems",
	"items": "NSMenuItems",
}


# Elements gormtool archives as their superclass.
# A restored control class needs its matching cell class too: NSSecureTextField,
# for one, sends -setEchosBullets: to its cell while decoding.
ARCHIVED_AS = {
	"secureTextField": "NSTextField",
	"secureTextFieldCell": "NSTextFieldCell",
	"searchField": "NSTextField",
	"searchFieldCell": "NSTextFieldCell",
	"tokenField": "NSTextField",
	"tokenFieldCell": "NSTextFieldCell",
}


CELL_FOR = {
	"NSSecureTextField": "NSSecureTextFieldCell",
	"NSSearchField": "NSSearchFieldCell",
	"NSTokenField": "NSTokenFieldCell",
}


def standard_class(tag):
	return "NS" + tag[0].upper() + tag[1:]


def compatible(tag, class_name):
	if class_name is None:
		return False
	if ARCHIVED_AS.get(tag) == class_name:
		return True
	t = tag.lower()
	c = class_name[2:].lower() if class_name.startswith("NS") else class_name.lower()
	if t == c:
		return True
	if t in ("customview", "view", "webview") and c in ("view", "customview"):
		return True
	if t == "window" and c == "windowtemplate":
		return True
	return False


def fmt_number(value):
	number = float(value)
	return str(int(number)) if number.is_integer() else value


def matches(nib, tag, index):
	"""Whether the archived object can be the xib element, looking through its
	class chain so objects whose class was already restored still match."""
	if nib.obj(index) is None:
		return False
	return any(compatible(tag, name) for name in [nib.class_name(index)] + nib.class_chain(index))


def map_objects(nib, xib_root, problems):
	"""Return {xib id: nib object index} by walking both object trees."""
	mapping = {}

	def walk(element, index):
		if not matches(nib, element.tag, index):
			problems.append("cannot match xib %s #%s with nib %s" % (element.tag, element.get("id"), nib.class_name(index)))
			return
		if element.get("id"):
			mapping[element.get("id")] = index
		for child in element:
			key = child.get("key")
			if key is None and child.tag in LISTS:
				kids = [k for k in child if k.get("id")]
				archived = nib.array(nib.ref(index, LISTS[child.tag]))
				position = 0
				for kid in kids:
					while position < len(archived) and not matches(nib, kid.tag, archived[position]):
						position += 1
					if position == len(archived):
						problems.append("xib %s #%s has no counterpart under %s #%s" % (kid.tag, kid.get("id"), element.tag, element.get("id")))
						break
					walk(kid, archived[position])
					position += 1
			elif key is None and child.tag == "cells":
				# A matrix lists its cells by column; the archive stores them
				# row by row.
				columns = [c for c in child if c.tag == "column"]
				archived = nib.array(nib.ref(index, "NSCells"))
				for column_number, column in enumerate(columns):
					cells = [c for c in column if c.get("id")]
					for row_number, cell in enumerate(cells):
						position = row_number * len(columns) + column_number
						if position < len(archived):
							walk(cell, archived[position])
						else:
							problems.append("matrix #%s has no cell for #%s" % (element.get("id"), cell.get("id")))
			elif key is not None:
				archived_key = KEYED_CHILDREN.get((element.tag, key)) or KEYED_ANY_PARENT.get(key)
				if archived_key and child.get("id") and nib.ref(index, archived_key):
					walk(child, nib.ref(index, archived_key))

	def trial(element, index):
		"""Mismatches when walking element against index (fewer is better)."""
		saved_mapping, saved_problems = dict(mapping), list(problems)
		walk(element, index)
		score = len(problems) - len(saved_problems)
		if element.tag == "menu":
			titles = [i.get("title", "") for i in element.iter("menuItem")][:len(nib.array(nib.ref(index, "NSMenuItems")))]
			archived = [nib.string(nib.ref(i, "NSTitle")) or "" for i in nib.array(nib.ref(index, "NSMenuItems"))]
			score += sum(1 for a, b in zip(titles, archived) if a != b) + abs(len(element.findall("items/menuItem")) - len(archived))
		mapping.clear(); mapping.update(saved_mapping)
		problems[:] = saved_problems
		return score

	owner = nib.root_ref("NSRoot")
	keys = nib.array(nib.root_ref("NSObjectsKeys"))
	values = nib.array(nib.root_ref("NSObjectsValues"))
	top_level = [k for k, v in zip(keys, values) if v == owner and k != owner]
	used = set()
	xib_windows = [e for e in xib_root.find("objects") if e.tag == "window"]
	windows_matched = [0]

	for element in xib_root.find("objects"):
		element_id = element.get("id", "")
		if element_id.startswith("-"):
			if element.get("userLabel") == "File's Owner":
				mapping[element_id] = owner
			continue
		if element.tag == "window":
			# gormtool moves windows vertically, so match on size and prefer
			# the exact rectangle when several windows share a size.
			rect = element.find("rect[@key='contentRect']")
			wanted = "{{%s, %s}, {%s, %s}}" % tuple(fmt_number(rect.get(a)) for a in ("x", "y", "width", "height"))
			size = "{%s, %s}}" % (fmt_number(rect.get("width")), fmt_number(rect.get("height")))
			windows = [t for t in top_level if t not in used and nib.class_name(t) == "NSWindowTemplate"]
			candidates = [t for t in windows if nib.string(nib.ref(t, "NSWindowRect")) == wanted] or \
				[t for t in windows if (nib.string(nib.ref(t, "NSWindowRect")) or "").endswith(size)]
			# Some windows are resized on conversion; a lone remaining window
			# can only be this one.
			if not candidates and len(windows) == 1 and len(xib_windows) - windows_matched[0] == 1:
				candidates = windows
			windows_matched[0] += 1
		else:
			candidates = [t for t in top_level if t not in used and matches(nib, element.tag, t)]
			if element.tag == "customObject":
				wanted_class = element.get("customClass", "NSObject")
				candidates = [t for t in candidates if nib.string(nib.ref(t, "NSClassName")) == wanted_class]
			# Top-level objects are not archived in xib order, so pick the
			# candidate whose subtree lines up with the element's.
			candidates.sort(key=lambda t: trial(element, t))
		if not candidates:
			problems.append("top-level xib %s #%s has no counterpart" % (element.tag, element_id))
			continue
		used.add(candidates[0])
		walk(element, candidates[0])
	return mapping


# ---- repairs --------------------------------------------------------------

def available_classes():
	"""Classes that exist at run time: GNUstep AppKit plus the app's sources."""
	names = set()
	for library in glob.glob("/System/Library/Libraries/libgnustep-gui.so.*"):
		out = subprocess.run(["nm", "-D", "--defined-only", library], capture_output=True, text=True).stdout
		names.update(re.findall(r"\._OBJC_CLASS_(\w+)$", out, re.M))
	makefile = open(os.path.join(SOURCE_ROOT, "GNUmakefile")).read()
	for source in re.findall(r"^\t(\S+\.m)", makefile, re.M):
		path = os.path.join(SOURCE_ROOT, source)
		if os.path.exists(path):
			names.update(re.findall(r"^@implementation\s+(\w+)\s*$", open(path).read(), re.M))
	return names


def placeholder_ids(xib_root):
	return {e.get("id"): e.get("userLabel") for e in xib_root.find("objects") if e.get("id", "").startswith("-")}


def xib_connections(xib_root):
	for element in xib_root.iter():
		connections = element.find("connections")
		if connections is None:
			continue
		for child in connections:
			yield element, child


def repair_connections(nib, xib_root, mapping, problems):
	"""Rewrite every outlet and action connector from the xib.

	gormtool keeps one connector per xib connection, but their endpoints are
	unreliable: placeholders come out nil, windows are replaced by copies that
	are not part of the object graph, and some action connectors even lose
	their control.  The object mapping gives the real endpoints, so each
	connector is matched to its xib connection by kind and label and has both
	ends set from it.  First Responder stays nil, which is how an action
	travels the responder chain.
	"""
	placeholders = placeholder_ids(xib_root)
	first_responder = next((i for i, label in placeholders.items() if label == "First Responder"), None)
	connectors = nib.array(nib.root_ref("NSConnections"))
	kinds = {"outlet": "NSNibOutletConnector", "action": "NSNibControlConnector"}
	taken = set()
	changed = 0

	for element, child in xib_connections(xib_root):
		if child.tag not in kinds:
			continue
		kind = kinds[child.tag]
		label = child.get("property") if child.tag == "outlet" else child.get("selector")
		target_id = child.get("destination") if child.tag == "outlet" else child.get("target")
		source = mapping.get(element.get("id"))
		destination = 0 if target_id == first_responder else mapping.get(target_id)
		if source is None or destination is None:
			problems.append("%s %s: endpoint #%s or #%s not found in nib" % (child.tag, label, element.get("id"), target_id))
			continue

		candidates = [c for c in connectors if c not in taken and nib.class_name(c) == kind
			and nib.string(nib.ref(c, "NSLabel")) == label]
		# Prefer the connector that already has the right ends, so repeated
		# labels (performClose: on every panel) pair up with their own control.
		candidates.sort(key=lambda c: ((nib.ref(c, "NSSource") or 0) != source,
			(nib.ref(c, "NSDestination") or 0) != destination))
		if candidates:
			connector_index = candidates[0]
		else:
			connector_index = nib.add({
				"$class": plistlib.UID(nib.class_ref(kind, [kind, "NSNibConnector", "NSObject"])),
				"NSLabel": plistlib.UID(nib.add_string(label)),
			})
			nib.obj(nib.root_ref("NSConnections"))["NS.objects"].append(plistlib.UID(connector_index))
		taken.add(connector_index)

		connector = nib.obj(connector_index)
		if (nib.ref(connector_index, "NSSource") or 0) != source or (nib.ref(connector_index, "NSDestination") or 0) != destination:
			connector["NSSource"] = plistlib.UID(source)
			connector["NSDestination"] = plistlib.UID(destination)
			changed += 1

	# gormtool adds a few connectors of its own (the font manager's menu
	# outlet, from systemMenu="font"); they are kept.
	for c in connectors:
		if c not in taken and nib.class_name(c) in kinds.values():
			print("  note: keeping %s %s added by gormtool" % (nib.class_name(c), nib.string(nib.ref(c, "NSLabel"))))
	return changed


def repair_classes(nib, xib_root, mapping, classes, problems):
	repaired = 0
	for element in xib_root.iter():
		custom = element.get("customClass")
		if not custom and element.tag in ARCHIVED_AS:
			custom = standard_class(element.tag)
		element_id = element.get("id", "")
		if not custom or element_id.startswith("-") or element.tag in ("customObject",):
			continue
		index = mapping.get(element_id)
		if index is None:
			problems.append("custom class %s: xib #%s not found in nib" % (custom, element_id))
			continue
		if element.tag == "window":
			current = nib.string(nib.ref(index, "NSWindowClass"))
			if current != custom:
				if custom not in classes:
					problems.append("window class %s is not available" % custom)
					continue
				nib.obj(index)["NSWindowClass"] = plistlib.UID(nib.add_string(custom))
				repaired += 1
			continue
		current = nib.class_name(index)
		if current in ("NSCustomView", custom):
			continue
		if custom not in classes:
			# A macOS-only class (e.g. NSVisualEffectView): the base class is
			# the closest thing GNUstep can load.
			print("  note: %s #%s stays %s (no %s here)" % (element.tag, element_id, current, custom))
			continue
		chain = [custom] + nib.class_chain(index)
		nib.obj(index)["$class"] = plistlib.UID(nib.class_ref(custom, chain))
		repaired += 1
		# Interface Builder lets a text field become an NSSecureTextField and
		# swaps the cell behind the scenes; GNUstep's classes insist on the
		# matching cell class while decoding.
		cell_class = CELL_FOR.get(custom)
		cell = nib.ref(index, "NSCell")
		if cell_class and cell and nib.class_name(cell) != cell_class:
			nib.obj(cell)["$class"] = plistlib.UID(nib.class_ref(cell_class, [cell_class] + nib.class_chain(cell)))
	return repaired


def archive_value(nib, element):
	if element.tag == "bool":
		return nib.add(element.get("value") == "YES")
	if element.tag == "integer":
		return nib.add(int(element.get("value")))
	if element.tag in ("real", "decimal"):
		return nib.add(float(element.get("value")))
	if element.tag == "string":
		return nib.add_string(element.text or element.get("value") or "")
	raise ValueError("unsupported binding option <%s>" % element.tag)


def repair_bindings(nib, xib_root, mapping, problems):
	connections = nib.obj(nib.root_ref("NSConnections"))
	existing = {(nib.ref(i, "NSSource"), nib.string(nib.ref(i, "NSBinding")))
		for i in nib.array(nib.root_ref("NSConnections")) if nib.class_name(i) == "NSNibBindingConnector"}
	connector_class = nib.class_ref("NSNibBindingConnector", ["NSNibBindingConnector", "NSNibConnector", "NSObject"])
	dictionary_class = nib.class_ref("NSDictionary", ["NSDictionary", "NSObject"])
	added = 0
	for element, child in xib_connections(xib_root):
		if child.tag != "binding":
			continue
		source = mapping.get(element.get("id"))
		destination = mapping.get(child.get("destination"))
		name, key_path = child.get("name"), child.get("keyPath")
		if source is None or destination is None:
			problems.append("binding %s -> %s on xib #%s: endpoint not found in nib" % (name, key_path, element.get("id")))
			continue
		if (source, name) in existing:
			continue
		connector = {
			"$class": plistlib.UID(connector_class),
			"NSSource": plistlib.UID(source),
			"NSDestination": plistlib.UID(destination),
			"NSLabel": plistlib.UID(nib.add_string("%s: %s" % (name, key_path))),
			"NSBinding": plistlib.UID(nib.add_string(name)),
			"NSKeyPath": plistlib.UID(nib.add_string(key_path)),
			"NSNibBindingConnectorVersion": 2,
		}
		options = child.find("dictionary[@key='options']")
		if options is not None and len(options):
			keys = [plistlib.UID(nib.add_string(o.get("key"))) for o in options]
			values = [plistlib.UID(archive_value(nib, o)) for o in options]
			connector["NSOptions"] = plistlib.UID(nib.add({"$class": plistlib.UID(dictionary_class), "NS.keys": keys, "NS.objects": values}))
		connections["NS.objects"].append(plistlib.UID(nib.add(connector)))
		added += 1
	return added


def repair_shared_defaults(nib, xib_root, mapping, problems):
	"""Mark shared user defaults controllers as such.

	gormtool drops representsSharedInstance, so GNUstep decodes a private
	controller with no defaults behind it and every binding to it reads nil.
	"""
	for element in xib_root.iter("userDefaultsController"):
		if element.get("representsSharedInstance") != "YES":
			continue
		index = mapping.get(element.get("id"))
		if index is None:
			problems.append("user defaults controller #%s not found in nib" % element.get("id"))
			continue
		nib.obj(index)["NSSharedInstance"] = True


def repair_content_view_autoresizing(nib, xib_root, mapping):
	"""Let window content views resize their subviews.

	The localized xibs were upgraded from old nibs by an Interface Builder
	that wrote autoresizesSubviews="NO" on every window content view, where
	the development-language xibs have the default.  Without it, a panel that
	resizes itself (New Connection collapsing its details) leaves its controls
	where they were, outside the smaller window.
	"""
	for window in xib_root.iter("window"):
		content = window.find("view[@key='contentView']")
		if content is None or content.get("autoresizesSubviews") != "NO":
			continue
		index = mapping.get(content.get("id"))
		if index is not None:
			nib.obj(index)["NSvFlags"] = nib.obj(index).get("NSvFlags", 0) | 0x100


def repair_table_columns(nib):
	"""Drop the empty prototype cell views gormtool writes into every column.

	GNUstep switches a table to view-based mode as soon as a column carries
	the key, even when it holds nil, and a view-based table draws no cells:
	every cell-based table and outline view comes up blank.
	"""
	for index in range(len(nib.objects)):
		column = nib.obj(index)
		if column is None or "NSPrototypeCellViews" not in column:
			continue
		if not nib.array(nib.ref(index, "NSPrototypeCellViews")):
			del column["NSPrototypeCellViews"]


def repair_visibility(nib, xib_root, mapping):
	visible = []
	for element in xib_root.find("objects"):
		if element.tag == "window" and element.get("visibleAtLaunch", "YES") == "YES":
			index = mapping.get(element.get("id"))
			if index is not None:
				visible.append(plistlib.UID(index))
	target = nib.root_ref("NSVisibleWindows")
	if target:
		nib.obj(target)["NS.objects"] = visible
	else:
		nib.root["NSVisibleWindows"] = plistlib.UID(nib.add({"$class": plistlib.UID(nib.class_ref("NSMutableArray", ["NSMutableArray", "NSArray", "NSObject"])), "NS.objects": visible}))
	# gormtool also stores the list at the top of the archive.
	nib.data["NSVisibleWindows"] = list(visible)


def repair_main_menu_name(nib, xib_root):
	if xib_root.find(".//menu[@systemMenu='main']") is not None:
		return
	values = nib.obj(nib.root_ref("NSNamesValues"))
	for position, value in enumerate(values["NS.objects"]):
		if nib.string(uid(value)) == "MainMenu":
			values["NS.objects"][position] = plistlib.UID(nib.add_string("Menu"))


# ---- conversion -----------------------------------------------------------

def preprocessed_xib(xib_path, workdir):
	text = open(xib_path, encoding="utf-8").read()
	text = re.sub(r"<webPreferences\b.*?</webPreferences>\s*", "", text, flags=re.S)
	text = re.sub(r"<webView\b", "<customView", text).replace("</webView>", "</customView>")
	# An empty autosave name means none, but GNUstep's xib reader tries to
	# store it under an empty defaults key and aborts the whole load.
	text = text.replace(' recentsAutosaveName=""', "")
	path = os.path.join(workdir, os.path.basename(xib_path))
	with open(path, "w", encoding="utf-8") as f:
		f.write(text)
	return path


def convert(xib_path, gormtool, classes):
	problems = []
	nib_dir = xib_path[:-len(".xib")] + ".nib"
	with tempfile.TemporaryDirectory() as workdir:
		source = preprocessed_xib(xib_path, workdir)
		output = os.path.join(workdir, os.path.basename(nib_dir))
		# gormtool takes the document to read behind --read; passing it as a
		# bare argument makes it open the output file instead.  It is run with
		# the stock theme so that no desktop theme can swizzle its way into
		# the archived cells.
		result = subprocess.run([gormtool, "-GSTheme", "GNUstep",
			"--read", os.path.basename(source), "--write", os.path.basename(output)],
			cwd=workdir, capture_output=True, text=True, timeout=60)
		archive_path = os.path.join(output, "keyedobjects.nib")
		# gormtool can crash while tearing down after it has written the nib,
		# so judge the result by the archive, not the exit status.
		if not os.path.isfile(archive_path):
			failure = [l for l in (result.stdout + result.stderr).splitlines() if "Exception" in l or "Failed" in l]
			return ["gormtool produced no nib (exit %d) %s" % (result.returncode, failure[-1:] if failure else "")]
		nib = Archive(archive_path)
		xib_root = ET.parse(xib_path).getroot()
		mapping = map_objects(nib, xib_root, problems)
		counts = (
			repair_connections(nib, xib_root, mapping, problems),
			repair_classes(nib, xib_root, mapping, classes, problems),
			repair_bindings(nib, xib_root, mapping, problems),
		)
		repair_shared_defaults(nib, xib_root, mapping, problems)
		repair_content_view_autoresizing(nib, xib_root, mapping)
		repair_table_columns(nib)
		repair_visibility(nib, xib_root, mapping)
		repair_main_menu_name(nib, xib_root)
		nib.save(archive_path)
		if os.path.isdir(nib_dir):
			shutil.rmtree(nib_dir)
		shutil.copytree(output, nib_dir)
		print("%s: %d connections, %d classes, %d bindings" % (os.path.relpath(nib_dir, SOURCE_ROOT), *counts))
	return problems


def main(argv):
	gormtool = shutil.which("gormtool") or "/Local/Library/Tools/gormtool"
	if argv[:1] == ["--gormtool"]:
		gormtool, argv = argv[1], argv[2:]
	if not argv:
		sys.exit(__doc__)
	if not os.access(gormtool, os.X_OK):
		sys.exit("xib2nib: gormtool not found at %s" % gormtool)
	xvfb = shutil.which("Xvfb")
	if not xvfb:
		sys.exit("xib2nib: Xvfb not found; gormtool needs an X server without a window manager")
	display = next(n for n in range(170, 270) if not os.path.exists("/tmp/.X11-unix/X%d" % n) and not os.path.exists("/tmp/.X%d-lock" % n))
	server = subprocess.Popen([xvfb, ":%d" % display, "-screen", "0", "1280x1024x24", "-nolisten", "tcp"],
		stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
	try:
		for _ in range(50):
			if os.path.exists("/tmp/.X11-unix/X%d" % display):
				break
			time.sleep(0.1)
		else:
			sys.exit("xib2nib: Xvfb :%d did not start" % display)
		os.environ["DISPLAY"] = ":%d" % display
		failed = convert_all(argv, gormtool)
	finally:
		server.terminate()
		server.wait()
	sys.exit(1 if failed else 0)


def convert_all(argv, gormtool):
	classes = available_classes()
	failed = False
	for xib in argv:
		try:
			problems = convert(os.path.abspath(xib), gormtool, classes)
		except Exception as error:
			problems = ["%s: %s" % (type(error).__name__, error)]
		for problem in problems:
			print("  ERROR %s: %s" % (xib, problem))
		failed = failed or bool(problems)
	return failed


if __name__ == "__main__":
	main(sys.argv[1:])
