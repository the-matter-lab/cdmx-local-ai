# Workshop card workflow

Run these commands from the repository root. Every write requires the exact
confirmation phrase printed by the script. Neither Wi-Fi credentials nor API
keys belong in the golden image.

1. List removable disks with `./host/list-disks.sh`.
2. Download and verify the pinned Radxa image with
   `./host/download-stock-image.sh`.
3. Make the stock master with
   `./host/flash-stock.sh --disk /dev/DISK`.
4. Boot that card in one ZERO 3W, install the workshop stack with the on-device
   installer, test it, remove all credentials/history, and shut down cleanly.
5. Put the master card back in the host and run
   `./host/capture-golden.sh --source /dev/DISK`.
6. For each new card, run
   `./host/flash-team.sh --team N --disk /dev/DISK`, where `N` is 1 through 10.

The final command verifies the compressed golden image, writes it, reads the
written bytes back, and only then writes `before.txt` plus `cdmx-team.env` to
the FAT `config` partition. The marker assigns `equipoN`; the on-device first
boot service consumes it. Wi-Fi remains unset so the venue credentials can be
entered locally after boot.

Golden capture is a full-device image. Target cards must therefore be at least
as large in bytes as the master card, even when both cards have the same
advertised capacity. Use one card model/batch for the master and all copies.
