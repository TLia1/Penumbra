"""Arch's package sources for penumbra-updates: the official repositories, and the AUR through
Paru or Yay when one is installed. Flatpak is handled by penumbra-updates itself."""
import shutil


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
