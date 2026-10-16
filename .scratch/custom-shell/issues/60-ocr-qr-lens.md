# Text, QR codes and Google Lens from a region

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Three tools that act on a picked region, with the screenshot keys' picker (issue 20:
the screen freezes, and a click takes a whole window):

- **Copy text:** read the text in the region (OCR) and copy it.
- **Scan a code:** read a QR code or barcode and copy its value. A link can be opened.
- **Search with Google Lens:** look the region up in Lens, in Firefox.

ambxst has all three (`scripts/ocr.sh`, `qr_scan.sh`, `google_lens.sh`); ideas only.

**What leaves the machine:** copy text and scan a code run here (tesseract, zbar) and
send nothing. Lens sends the image to Google. ambxst's way also uploads it to uguu.se,
a public file host, so anyone with the link can fetch it while that host keeps it.

Checked: tesseract 5.5.3 and zbar 0.23.93 are in nixpkgs, and both leave with issue 23.
nixpkgs' tesseract carries every language: 1016 MB of data. Built with English only,
23 MB. grimblast saves the region to a file (`--freeze save area <file>`).

## Proposed choices

1. **New actions in the `screenshot` script: `screenshot text`, `qr` and `lens`.** The
   image goes to a temporary file in `$XDG_RUNTIME_DIR` and is removed after.
   Alternative: a separate script. Reason: the same picker and the same rules.
2. **English only: `tesseract.override { enableLanguages = [ "eng" ]; }`.**
   Alternative: a list of languages in Nix (ambxst's copy has seven: 196 MB).
3. **Results:** text goes to the clipboard, and the notification shows its first lines.
   A code's value goes to the clipboard; a link gets an Open button (Firefox). Several
   codes are copied one per line. "No text found" or "No code found" otherwise.
4. **Lens: copy the region to the clipboard and open `https://lens.google.com` in
   Firefox; you paste it there.** The image then goes only to Google, and only when
   you paste. Alternatives: ambxst's upload to uguu.se, then
   `lens.google.com/uploadbyurl?url=…` (one step fewer, but the image sits on a public
   host); or no Lens. Unchecked: whether Lens's page takes a pasted image.
5. **Keys (free today): Super+Print copies text; Super+Shift+Print scans a code. Lens
   only from the launcher.** Launcher actions (`>`): "Copy text from a region", "Scan a
   QR code or barcode", "Search a region with Google Lens". Not Alt+Print: with Alt,
   that key gives Sys_Req (xkeyboard-config's `pc` symbols). Alternative: launcher only.
6. **Packages:** the English tesseract and zbar, on the script's `PATH`. Lens needs
   nothing new (wl-copy, xdg-open and Firefox are installed); ambxst's way adds curl.
7. **Cost:** nothing runs until used; each use is one picker and one short process.

## Acceptance criteria

- [ ] Super+Print over some text puts the text on the clipboard and in a notification.
      Escape in the picker cancels quietly.
- [ ] Super+Shift+Print over a QR code, and over a barcode, copies the value. A link
      offers Open.
- [ ] A region with no text or code says so.
- [ ] Copy text and scan a code call nothing that uses the network.
- [ ] The temporary image is removed after each use.
- [ ] The binds show in the cheatsheet, and the launcher actions work.
- [ ] (You, as it uses the network) the Lens action opens Lens, and the pasted region
      gives results.
- [ ] Nothing runs until used; costs nothing in game mode.

## Blocked by

- None
