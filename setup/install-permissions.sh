#!/usr/bin/env bash
set -euo pipefail
if [[ $EUID != 0 || $# != 1 || $1 == root ]]; then
  echo 'Usage: sudo bash setup/install-permissions.sh YOUR_LOGIN' >&2
  exit 1
fi
id "$1" >/dev/null
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
getent group clevo-rgb >/dev/null || groupadd --system clevo-rgb
usermod -aG clevo-rgb "$1"
install -m 0644 "$source_dir/70-clevo-rgb.rules" /etc/udev/rules.d/70-clevo-rgb.rules
udevadm control --reload-rules
for attribute in brightness multi_intensity; do
  file="/sys/class/leds/rgb:kbd_backlight/$attribute"
  if [[ -e $file ]]; then
    chgrp clevo-rgb "$file"
    chmod g+w "$file"
  fi
done
echo 'Permissions installed. Log out and back in for group membership to take effect.'
