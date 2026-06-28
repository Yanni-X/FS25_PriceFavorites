"""Build the installable FS25_PriceFavorites.zip.

Uses Python's zipfile, which writes spec-compliant forward-slash entry paths.
(PowerShell's Compress-Archive writes backslashes, which FS25 cannot resolve for
files in subfolders like scripts/.)

The release zip contains ONLY the runtime files, with modDesc.xml at the root.
"""
import os
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))   # tools/
ROOT = os.path.dirname(HERE)                          # repo root (mod root)
OUT = os.path.join(ROOT, "FS25_PriceFavorites.zip")

FILES = [
    "modDesc.xml",
    "modIcon.dds",
    "scripts/PriceFavorites.lua",
]

if os.path.exists(OUT):
    os.remove(OUT)

with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
    for rel in FILES:
        src = os.path.join(ROOT, rel.replace("/", os.sep))
        if not os.path.exists(src):
            raise SystemExit("missing file: " + src)
        z.write(src, arcname=rel)   # arcname forces forward-slash entry

print("built", OUT)
with zipfile.ZipFile(OUT) as z:
    for n in z.namelist():
        print("  ", n)
