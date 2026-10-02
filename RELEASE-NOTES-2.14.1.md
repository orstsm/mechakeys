# MechaKeys 2.14.1

- Replace dynamic menu-bar scene insertion with an explicitly owned native status item and popover. Presentation switches happen after the current click finishes.
- Recreate keyboard monitoring and refresh audio-device and microphone state after system wake or session reactivation, with one bounded settling check and no continuous polling.
- Keep idle audio suspended until input arrives after waking, unless a playback-policy change requires enabling audio.
- Restore island hover after wake and remove animation-completion-dependent click handling.
- Catch legacy audio-player exceptions during output-device interruptions instead of aborting the app; retry on the next input without replaying stale sounds.
- All playback and presentation controls continue to work offline; only optional update checks need internet access.
