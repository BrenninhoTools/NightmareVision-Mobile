import os
import sys


def main():
    root = sys.argv[1]
    limit = int(sys.argv[2]) * 1024 * 1024
    keep = float(sys.argv[3]) if len(sys.argv) > 3 else 0.75

    if not os.path.isdir(root):
        return

    entries = []
    total = 0

    for folder, _, files in os.walk(root):
        for name in files:
            path = os.path.join(folder, name)
            try:
                info = os.stat(path)
            except OSError:
                continue
            entries.append((max(info.st_atime, info.st_mtime), info.st_size, path))
            total += info.st_size

    print(f"hxcpp cache: {total // (1024 * 1024)} MB in {len(entries)} files")

    if total <= limit:
        return

    target = limit * keep
    removed = 0

    for _, size, path in sorted(entries):
        if total <= target:
            break
        try:
            os.remove(path)
            total -= size
            removed += 1
        except OSError:
            pass

    print(f"hxcpp cache pruned: removed {removed} files, now {total // (1024 * 1024)} MB")


if __name__ == "__main__":
    main()
