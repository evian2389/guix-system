# Follow-up notes

## Steam menus disappear in Niri

- Symptom: Steam menus such as **Steam**, **View**, and **Friends** appear briefly, then close.
- Likely cause from the prior Codex conversation: an `xwayland-satellite` 0.8.2 popup-focus regression; that conversation reported the fix in 0.8.3.
- Repo state checked 2026-10-09: Niri starts `xwayland-satellite` (`src/raynet-guix/users/orka/files/.config/niri/config.kdl`), Guix Home includes the package (`src/raynet-guix/users/common.scm`), and `guix show xwayland-satellite` reports 0.8.2. No Steam-specific popup rule is configured.
- Later check: verify the Guix channel provides 0.8.3 or newer, update/reconfigure Guix Home if needed, restart the Niri session, and confirm Steam menus stay open.
- Conversation follow-up: **“Recheck Steam popup after xwayland-satellite 0.8.3.”**
