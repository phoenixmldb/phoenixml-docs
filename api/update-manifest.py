#!/usr/bin/env python3
"""Updates the Crucible site manifest to include API reference pages."""
import os
import sys
import xml.etree.ElementTree as ET

if len(sys.argv) < 2:
    print("Usage: update-manifest.py <intermediate-dir>", file=sys.stderr)
    sys.exit(1)

intermediate_dir = sys.argv[1]
manifest_path = os.path.join(intermediate_dir, "site-manifest.xml")

if not os.path.exists(manifest_path):
    print(f"Manifest not found: {manifest_path}", file=sys.stderr)
    sys.exit(1)

tree = ET.parse(manifest_path)
root = tree.getroot()

api_dir = os.path.join(intermediate_dir, "api")
if not os.path.isdir(api_dir):
    print("No api/ directory found, skipping manifest update", file=sys.stderr)
    sys.exit(0)

# Add API Reference section
api_section = ET.SubElement(root, "section", path="api", title="API Reference", sort="6")

libraries = [
    ("core", "Core"),
    ("xdm", "XDM"),
    ("xquery", "XQuery"),
    ("xslt", "XSLT"),
]

total_pages = 0
for lib_dir, lib_name in libraries:
    lib_path = os.path.join(api_dir, lib_dir)
    if not os.path.isdir(lib_path):
        continue

    section = ET.SubElement(api_section, "section",
                           path=f"api/{lib_dir}",
                           title=f"PhoenixmlDb.{lib_name}")

    # Add index page
    ET.SubElement(section, "page",
                 path=f"api/{lib_dir}/index",
                 title=f"PhoenixmlDb.{lib_name} API",
                 sort="0")
    total_pages += 1

    # Add type pages
    for filename in sorted(os.listdir(lib_path)):
        if not filename.endswith(".xml") or filename == "index.xml":
            continue

        filepath = os.path.join(lib_path, filename)
        page_path = f"api/{lib_dir}/{filename[:-4]}"

        try:
            doc = ET.parse(filepath)
            title = doc.getroot().get("title", filename[:-4])
        except Exception:
            title = filename[:-4]

        ET.SubElement(section, "page", path=page_path, title=title)
        total_pages += 1

ET.indent(tree, space="  ")
tree.write(manifest_path, xml_declaration=True, encoding="unicode")
print(f"  Added {total_pages} API pages to manifest", file=sys.stderr)
