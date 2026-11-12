import hashlib
import json
import os
import sys


def digest(path):
    hasher = hashlib.sha1()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def main():
    root = sys.argv[1]
    manifest_path = sys.argv[2]
    mode = sys.argv[3]

    previous = {}
    if os.path.isfile(manifest_path):
        try:
            with open(manifest_path) as handle:
                previous = json.load(handle)
        except (OSError, ValueError):
            previous = {}

    current = {}
    for folder, _, files in os.walk(root):
        for name in files:
            if name.lower().endswith(".png"):
                path = os.path.join(folder, name)
                current[path] = digest(path)

    if mode == "prepare":
        removed = 0
        for folder, _, files in os.walk(root):
            for name in files:
                if not name.lower().endswith(".astc"):
                    continue
                astc = os.path.join(folder, name)
                png = astc[:-5] + ".png"
                if png not in current or previous.get(png) != current[png]:
                    os.remove(astc)
                    removed += 1
        print(f"ASTC: {removed} outdated textures removed")
    else:
        os.makedirs(os.path.dirname(manifest_path) or ".", exist_ok=True)
        with open(manifest_path, "w") as handle:
            json.dump(current, handle)
        print(f"ASTC: manifest written for {len(current)} images")


if __name__ == "__main__":
    main()
