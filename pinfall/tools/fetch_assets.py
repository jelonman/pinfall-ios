#!/usr/bin/env python3
"""Pull real PBR textures from Poly Haven (CC0) into the Godot project.

Owner, 2026-08-01: *"proper assets, proper graphics, high definition, high quality, high
textures, high resolution... don't make them like some weird Minecraft stuff."*

The three existing "games" are 28-32 KB single-file canvases with no assets at all. That is
what he is rejecting, and he is right — Apple rejects that class under Guideline 4.2 anyway.
This fetches the real thing: photoscanned PBR sets, CC0, no attribution required, no licence
risk on a paid app.

2K, not 4K, and that is a decision rather than a shortcut. A phone samples these at a few
hundred pixels on screen; 4K quadruples memory and download size for detail no device resolves.
The look comes from the ROUGHNESS and NORMAL maps being real scans, not from resolution.

    fetch_assets.py            # download the set
    fetch_assets.py --list     # show what would be fetched
"""
from __future__ import annotations

import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "art", "textures")
API = "https://api.polyhaven.com"
RES = "2k"
# Poly Haven's CDN 403s a bare urllib request; it wants a browser-shaped User-Agent.
UA = {"User-Agent": "Mozilla/5.0 (pinfall-assetfetch)"}
FMT = "jpg"

# One material per surface the game actually shows. Chosen for CONTRAST between them — a
# puzzle read at arm's length on a phone needs the pin, the wall and the hazard to be
# instantly distinguishable, which is a material problem before it is a colour problem.
WANTED = {
    "pin": "metal_plate",            # the pins the player pulls: bright, hard, specular
    "wall": "concrete_wall_008",     # the chamber: matte, mid-value, keeps the pins readable
    "floor": "rock_wall_10",         # the base: coarse, dark, anchors the composition
    "accent": "rusty_metal_02",      # the hazard housing: warm, damaged, reads as danger
}

# The maps a Godot StandardMaterial3D actually consumes, each with the aliases Poly Haven
# really uses. The first attempt hard-coded lowercase `diff`/`rough` and silently fetched
# nothing but normals — the API returns `Diffuse`, `Rough`, `Metal`, capitalised, and it is
# not consistent across assets. Probe a candidate list per role instead of guessing one name.
#
# Displacement and AO are deliberately skipped: the mobile renderer ignores parallax, and
# baking AO into a tiling texture double-darkens every crevice once real lighting lands on it.
MAPS = {
    "albedo":    ("Diffuse", "diff", "albedo", "Albedo", "col", "Color"),
    "normal":    ("nor_gl", "nor_dx", "Normal", "normal"),
    "roughness": ("Rough", "rough", "Roughness", "roughness"),
    "metallic":  ("Metal", "metal", "Metallic", "metallic"),
}


def get(url: str):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def download(url: str, dest: str) -> int:
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=180) as r, open(dest, "wb") as f:
        data = r.read()
        f.write(data)
    return len(data)


def main() -> int:
    listing = get(f"{API}/assets?type=textures")
    total = 0
    for role, asset in WANTED.items():
        if asset not in listing:
            print(f"  ! {asset} not in the Poly Haven index — skipping {role}")
            continue
        if "--list" in sys.argv:
            print(f"  {role:<7} {asset}")
            continue
        files = get(f"{API}/files/{asset}")
        for label, keys in MAPS.items():
            node = None
            for key in keys:
                node = files.get(key, {}).get(RES, {}).get(FMT)
                if node:
                    break
            if not node:
                # metallic is genuinely absent on non-metal scans; that is correct, not a fault.
                if label != "metallic":
                    print(f"  ! {asset}: no {label} at {RES}/{FMT} "
                          f"(tried {', '.join(keys)}; available: {', '.join(list(files)[:6])})")
                continue
            dest = os.path.join(OUT, role, f"{label}.jpg")
            n = download(node["url"], dest)
            total += n
            print(f"  {role:<7} {label:<9} {n/1024:7.0f} KB  {os.path.relpath(dest, HERE)}")
    if "--list" not in sys.argv:
        print(f"\n{total/1024/1024:.1f} MB of CC0 PBR into {os.path.relpath(OUT, HERE)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
