# REAPER Utility Scripts

A collection of Lua (and other) scripts and tools for [REAPER](https://www.reaper.fm/) to automate and enhance your workflow. These utilities help with MIDI, audio automation, and other common tasks in REAPER projects.

## Scripts

### [`autoCC.lua`](t:/Downloads/autoCC/autoCC.lua)
Maps audio automation envelope points from selected tracks to MIDI CC events in a "Target" track.  
- Each envelope is mapped to a unique MIDI CC lane.
- MIDI items are created in the "Target" track containing CC data.
- Handles tracks with no envelopes gracefully.
- Uses REAPER's Undo system for safe operation.

## Usage

1. Download or clone this repository.
2. Place the desired Lua script(s) in your REAPER scripts directory.
3. In REAPER, use the Actions list to run or assign scripts to shortcuts.

## Contributing

Feel free to submit pull requests with new utility scripts or improvements!

## License

MIT License. See [LICENSE](LICENSE)
