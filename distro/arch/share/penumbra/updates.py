"""Arch's package sources for penumbra-updates: the official repositories, and the AUR through
Paru or Yay when one is installed. Flatpak is handled by penumbra-updates itself. Also the Arch
news since the last upgrade (some upgrades need a step by hand) and whether a restart is due."""
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
import os
from pathlib import Path
import re
import shutil
import urllib.request
from xml.etree import ElementTree

PACMAN_LOG = Path("/var/log/pacman.log")
NEWS_FEED = "https://archlinux.org/feeds/news/"
# Updated while running, these only take full effect after a restart.
CORE = ("glibc", "systemd", "linux-firmware", "mesa", "nvidia", "nvidia-open", "nvidia-utils",
        "amd-ucode", "intel-ucode", "dbus", "dbus-broker", "wayland", "hyprland")


def aur_helper():
    return shutil.which("paru") or shutil.which("yay")


def sources():
    """The checks to run. Each lists one pending update per line, "name old -> new"; `empty` are
    exit codes that mean nothing to update, `empty_if_silent` the same when nothing is printed."""
    # checkupdates uses a separate database, so it never refreshes the live pacman one.
    found = [{"name": "Arch", "command": ["checkupdates", "--nocolor"], "empty": (2,)}]
    aur = aur_helper()
    if aur:
        # Yay returns 1 with no output when no AUR upgrades are available.
        found.append({"name": "AUR", "command": [aur, "-Qua", "--color", "never"], "empty_if_silent": (1,)})
    return found


def notes():
    """Extra lines for the bar's tooltip."""
    return [] if aur_helper() else ["AUR: install yay or paru to enable"]


def upgrades():
    """(name, command) for each upgrade step, run in order in a terminal."""
    aur = aur_helper()
    return [("Arch + AUR", [aur, "-Syu"]) if aur else ("Arch", ["sudo", "pacman", "-Syu"])]


def _log_lines():
    try:
        return PACMAN_LOG.read_text(errors="replace").splitlines()
    except OSError:
        return []


def _when(line):
    """The time a pacman.log line was written, or None."""
    m = re.match(r"^\[([^\]]+)\]", line)
    try:
        return datetime.fromisoformat(m.group(1)) if m else None
    except ValueError:
        return None


def last_upgrade():
    """When the last full system upgrade started, or None."""
    for line in reversed(_log_lines()):
        if "starting full system upgrade" in line:
            return _when(line)
    return None


def news(cache, limit=4, fetch=urllib.request.urlopen):
    """The latest Arch news items: [{title, link, date (ISO), new (since the last upgrade)}]. The
    feed is fetched at most every three hours and kept in `cache` (a Path)."""
    try:
        fresh = datetime.now().timestamp() - cache.stat().st_mtime < 3 * 3600
    except OSError:
        fresh = False
    if fresh:
        data = cache.read_bytes()
    else:
        with fetch(NEWS_FEED, timeout=10) as response:
            data = response.read(1 << 20)
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_bytes(data)
    root = ElementTree.fromstring(data)
    since = last_upgrade()
    items = []
    for item in root.iter("item"):
        try:
            date = parsedate_to_datetime(item.findtext("pubDate") or "")
        except (TypeError, ValueError):
            continue
        items.append({"title": (item.findtext("title") or "").strip(), "link": (item.findtext("link") or "").strip(),
                      "date": date.astimezone(timezone.utc).isoformat(), "new": bool(since and date > since)})
    return sorted(items, key=lambda i: i["date"], reverse=True)[:limit]


def restart_reasons():
    """Why a restart is due: a new kernel, or core packages upgraded since the computer started."""
    reasons = []
    if not Path("/usr/lib/modules", os.uname().release).is_dir():
        reasons.append("The kernel was updated")
    try:
        booted = datetime.fromtimestamp(next(int(l.split()[1]) for l in Path("/proc/stat").read_text().splitlines()
                                             if l.startswith("btime ")), timezone.utc)
    except (OSError, StopIteration, ValueError):
        return reasons
    upgraded = set()
    for line in _log_lines():
        m = re.search(r"\[ALPM\] upgraded (\S+) ", line)
        when = _when(line) if m else None
        if m and m.group(1) in CORE and when and when > booted:
            upgraded.add(m.group(1))
    if upgraded:
        names = sorted(upgraded)
        joined = ", ".join(names[:-1]) + " and " + names[-1] if len(names) > 1 else names[0]
        reasons.append(f"{joined} {'were' if len(names) > 1 else 'was'} updated")
    return reasons
