#!/usr/bin/env python3
#
# Copyright (c) 2026 Simon Peter
#
# SPDX-License-Identifier: BSD-2-Clause
#
"""Produce the images Colloquy looks up by name, in formats GNUstep can load.

On macOS the images come from an asset catalog (Mac-Old.xcassets), which
GNUstep does not read, and many of them - like the loose images in
Misc Images - are PDFs, which GNUstep's NSImage cannot draw.  The interfaces
also use system images such as NSActionTemplate that GNUstep does not ship;
those are drawn in gnustep/Images/*.eps.  Every image is therefore written to
gnustep-app/Images as <name>.png, where <name> is the name the code passes to
+imageNamed: (the image set's name for catalog images, the file name
otherwise).  PNGs are copied; PDFs and EPS files are rendered at 72 dpi so
the bitmap has the image's size in points.

Usage: images.py
Requires Ghostscript (gs) for the PDFs.  Exits non-zero if an image could not
be produced.
"""

import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE_ROOT = os.path.dirname(HERE)
CATALOG = os.path.join(SOURCE_ROOT, "Mac-Old/Mac-Old/Resources/Mac-Old.xcassets")
LOOSE = os.path.join(SOURCE_ROOT, "Mac-Old/Mac-Old/Resources/Misc Images")
SYSTEM = os.path.join(HERE, "Images")
OUTPUT = os.path.join(SOURCE_ROOT, "gnustep-app/Images")


def catalog_images():
	for root, dirs, files in os.walk(CATALOG):
		if not root.endswith(".imageset"):
			continue
		name = os.path.basename(root)[:-len(".imageset")]
		with open(os.path.join(root, "Contents.json")) as f:
			entries = json.load(f).get("images", [])
		# Prefer the 1x rendition; vector PDFs carry no scale at all.
		files = [e for e in entries if e.get("filename")]
		files.sort(key=lambda e: e.get("scale", "1x") != "1x")
		if not files:
			raise ValueError("image set %s has no image file" % name)
		yield name, os.path.join(root, files[0]["filename"])


def vector_images(directory, extension):
	for filename in sorted(os.listdir(directory)):
		base, ext = os.path.splitext(filename)
		if ext.lower() == extension:
			yield base, os.path.join(directory, filename)


def render(source, destination, gs):
	if source.lower().endswith(".png"):
		shutil.copyfile(source, destination)
		return
	crop = "-dEPSCrop" if source.lower().endswith(".eps") else "-dUseCropBox"
	subprocess.run([gs, "-q", "-dSAFER", "-dBATCH", "-dNOPAUSE", "-sDEVICE=pngalpha", "-r72",
		crop, "-dTextAlphaBits=4", "-dGraphicsAlphaBits=4",
		"-sOutputFile=" + destination, source], check=True, capture_output=True)


def main():
	gs = shutil.which("gs")
	if not gs:
		sys.exit("images.py: Ghostscript (gs) is needed to render the PDF and EPS images")
	os.makedirs(OUTPUT, exist_ok=True)
	produced = {}
	failed = False
	for name, source in list(catalog_images()) + list(vector_images(LOOSE, ".pdf")) + list(vector_images(SYSTEM, ".eps")):
		if name in produced:
			print("ERROR %s: provided by both %s and %s" % (name, produced[name], source))
			failed = True
			continue
		produced[name] = source
		try:
			render(source, os.path.join(OUTPUT, name + ".png"), gs)
		except (subprocess.CalledProcessError, OSError) as error:
			print("ERROR %s: %s" % (source, error))
			failed = True
	for stale in sorted(set(os.listdir(OUTPUT)) - {n + ".png" for n in produced}):
		os.remove(os.path.join(OUTPUT, stale))
	print("%d images in %s" % (len(produced), os.path.relpath(OUTPUT, SOURCE_ROOT)))
	sys.exit(1 if failed else 0)


if __name__ == "__main__":
	main()
