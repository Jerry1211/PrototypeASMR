# PrototypeASMR

PrototypeASMR is a World of Warcraft addon that plays customizable sound effects when mounting specific mounts.
It includes a full in-game GUI for managing mount to sound mappings, testing sounds, and controlling behavior.

The GUI is implemented in a separate file and does NOT modify the core addon logic.

---

## Features

- Play random sounds when mounting specific mounts
- Per-mount sound lists
- Full in-game GUI (/asmrgui)
- Add, remove, and clear sounds with confirmation dialogs
- Test individual sounds or random playback
- Supports current mount detection
- Clean dark UI with mint/green accent
- SavedVariables support (settings persist across sessions)

---

## Files

PrototypeASMR/
- PrototypeASMR.lua   (core addon logic)
- PrototypeGUI.lua    (GUI, does not modify core logic)
- PrototypeASMR.toc

---

## How It Works

- The core addon listens for UNIT_SPELLCAST_SUCCEEDED
- When a mount spell is detected, it checks if that mount has sounds assigned
- One sound is randomly selected and played
- The GUI interacts only with PrototypeASMRDB (SavedVariables)

---

## GUI

Open the GUI with:

/asmrgui

### GUI Capabilities

- Enable or disable the addon
- Use current mounted mount or manually enter a MountID
- Add sounds to a mount
- Remove sounds (with confirmation)
- Clear all sounds for a mount (with confirmation)
- Play a specific SoundID
- Play a random sound assigned to the mount
- Scrollable list of assigned sounds

---

## SavedVariables

PrototypeASMRDB structure:

- enabled (boolean)
- mounts (table)
  - key: MountID
  - value: list of SoundIDs

---

## Development Notes

- GUI is fully isolated from core logic
- No dependency on external addons
- Uses Blizzard native APIs only
- Designed for modern WoW clients (Dragonflight / TWW)

---

## License

MIT – free to use, modify, and redistribute.
