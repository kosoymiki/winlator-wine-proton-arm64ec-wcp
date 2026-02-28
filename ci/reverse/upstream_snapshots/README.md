## Upstream Snapshot Mirror

This directory is populated by `ci/reverse/harvest-transfer.sh` /
`ci/reverse/harvest_transfer.py`.

Purpose:
- keep lightweight, deterministic snapshots of selected upstream focus files;
- avoid full local source clones during ongoing reverse-intake cycles;
- provide stable inputs for patch drafting and conflict analysis.

Generation controls:
- `HARVEST_TRANSFER_AUTO_FOCUS_SYNC=1` enables auto-sync from `focus_paths`;
- `HARVEST_TRANSFER_INCLUDE_UNMAPPED=1` includes repos not listed in `transfer_map.json`;
- `HARVEST_TRANSFER_APPLY=1` writes snapshots into this tree.

Do not edit mirrored files manually. Update via harvest scripts.
