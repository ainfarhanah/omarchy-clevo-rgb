# Validation — 2026-10-20

Test machine: Clevo NH5xAx, tuxedo-keyboard 3.2.10, kernel 7.2.8-9-omarchy.

## Completed

- Verified actual sysfs RGB order and maxima; all maxima are 255.
- Confirmed helper refuses writes without permissions.
- Installed dedicated clevo-rgb group and udev rule; verified both writable
  attributes are root:clevo-rgb, mode 0664.
- Tested low and higher brightness, red, green, and blue as the normal user
  with the keyboard group; readback passed and starting settings were restored.
- User confirmed visible color changes and successful panel control.
- Inspected live panel layout, system font bindings, picker, and eight presets.
- Tested rapid color selection using an isolated QML panel and a delayed fake
  helper: red was written first, intermediate green was superseded, final blue
  was written, and the pending queue cleared. No hardware writes in this test.
- User confirmed immediate color controls work.
- Five Python fixture tests, Omarchy manifest validation, and permission
  installer syntax checks passed.

## Limitations / remaining release check

- Logout/login retained old desktop groups. Relaunching the bar in the dedicated
  group enabled access for the session. Verify normal startup after a full reboot,
  including persistence of the udev rule. No reboot has been performed by the agent.
- No other keyboard model or driver version has been tested.
- No clean-machine installation test has been performed.

## Publication preparation

- MIT license and manifest author added using the configured Git author name.
- README documents current behavior, dependencies, installation, access setup,
  removal, and troubleshooting.
- Screenshot contains only the plugin panel.
- GitHub publication target: https://github.com/ainfarhanah/omarchy-clevo-rgb
- No marketplace submission has been created.
