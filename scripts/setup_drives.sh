#!/usr/bin/env bash
# setup_drives.sh
#
# Partition (GPT), format (ext4), mount and register in /etc/fstab two NEW, EMPTY drives.
#
# WARNING: THIS ERASES THE TARGET DRIVES. Read docs/03-safety-checklist.md first.
# Run with:  sudo bash scripts/setup_drives.sh
#
# The script refuses to continue if a target drive:
#   - is not a block device,
#   - is, or contains, a mounted filesystem,
#   - already has partitions or a filesystem signature,
#   - does not match the expected model string (if EXPECTED_MODEL is set), or
#   - does not match the expected serial (if EXPECTED_SERIAL1 / EXPECTED_SERIAL2 are set).

set -euo pipefail

# ---------------- EDIT THESE ----------------
DEV1="/dev/sdb"
DEV2="/dev/sdc"
LABEL1="data1"
LABEL2="data2"
MOUNT1="/mnt/data1"
MOUNT2="/mnt/data2"

# Strongly recommended: fill these in so the script cannot hit the wrong drive.
EXPECTED_MODEL=""     # e.g. "ST4000NM000B"  (leave empty to skip the model check)
EXPECTED_SERIAL1=""   # serial of DEV1 (leave empty to skip)
EXPECTED_SERIAL2=""   # serial of DEV2 (leave empty to skip)

# Optional: add x-gvfs-show so the drives appear in the GNOME file manager sidebar (cosmetic).
FSTAB_EXTRA_OPTS=""   # e.g. ",x-gvfs-show"
# --------------------------------------------

OWNER="${SUDO_USER:-$USER}"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: run this script with sudo." >&2
  exit 1
fi

# ---- safety checks ----
check_device() {
  local dev="$1" expected_serial="$2"

  [ -b "$dev" ] || { echo "ERROR: $dev is not a block device. Aborting." >&2; exit 1; }

  # Mounted (the disk or any partition of it)?
  if lsblk -no MOUNTPOINT "$dev" | grep -q .; then
    echo "ERROR: $dev or a partition on it is mounted. Aborting." >&2
    exit 1
  fi

  # Already has partitions or a filesystem signature?
  if [ -n "$(lsblk -no FSTYPE "$dev" | tr -d '[:space:]')" ] || \
     [ "$(lsblk -no NAME "$dev" | wc -l)" -gt 1 ]; then
    echo "ERROR: $dev already has partitions or a filesystem. Aborting (refusing to erase data)." >&2
    exit 1
  fi

  # Model check
  if [ -n "$EXPECTED_MODEL" ]; then
    local model
    model="$(lsblk -dno MODEL "$dev" | tr -d '[:space:]')"
    case "$model" in
      *"$EXPECTED_MODEL"*) ;;
      *) echo "ERROR: $dev model '$model' does not match '$EXPECTED_MODEL'. Aborting." >&2; exit 1 ;;
    esac
  fi

  # Serial check
  if [ -n "$expected_serial" ]; then
    local serial
    serial="$(lsblk -dno SERIAL "$dev" | tr -d '[:space:]')"
    if [ "$serial" != "$expected_serial" ]; then
      echo "ERROR: $dev serial '$serial' does not match expected '$expected_serial'. Aborting." >&2
      exit 1
    fi
  fi
}

check_device "$DEV1" "$EXPECTED_SERIAL1"
check_device "$DEV2" "$EXPECTED_SERIAL2"

# Refuse to run if either mount point is already in /etc/fstab (avoids duplicate lines).
for M in "$MOUNT1" "$MOUNT2"; do
  if grep -Eq "^[^#]*[[:space:]]${M}[[:space:]]" /etc/fstab; then
    echo "ERROR: $M is already listed in /etc/fstab. Aborting to avoid duplicates." >&2
    exit 1
  fi
done

echo "About to ERASE and set up:"
lsblk -o NAME,SIZE,MODEL,SERIAL "$DEV1" "$DEV2"
read -r -p "Type YES to continue: " CONFIRM
[ "$CONFIRM" = "YES" ] || { echo "Cancelled."; exit 1; }

prepare() {
  local dev="$1" label="$2" mnt="$3"
  parted -s "$dev" mklabel gpt mkpart primary ext4 0% 100%
  partprobe "$dev"
  udevadm settle
  mkfs.ext4 -m 0 -L "$label" "${dev}1"
  mkdir -p "$mnt"
  local uuid
  uuid="$(blkid -s UUID -o value "${dev}1")"
  echo "UUID=${uuid}  ${mnt}  ext4  defaults,nofail${FSTAB_EXTRA_OPTS}  0  2" >> /etc/fstab
}

cp /etc/fstab /etc/fstab.bak
echo "Backed up /etc/fstab to /etc/fstab.bak"

prepare "$DEV1" "$LABEL1" "$MOUNT1"
prepare "$DEV2" "$LABEL2" "$MOUNT2"

systemctl daemon-reload
mount -a
chown "$OWNER:$OWNER" "$MOUNT1" "$MOUNT2"

echo
echo "Done. Result:"
df -h "$MOUNT1" "$MOUNT2"
echo
echo "Verify with:  findmnt $MOUNT1  &&  findmnt $MOUNT2"
