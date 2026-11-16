# Troubleshooting

Problems that came up during a real installation, and a few common extras.

## `mount -a` says "already mounted or mount point busy"

```
mount: /mnt/data1: /dev/sdb1 already mounted or mount point busy.
```

**Cause:** after `sudo systemctl daemon-reload`, systemd re-reads `/etc/fstab` and may remount the drives on its own, so `mount -a` finds them already mounted.

**Check:** `df -h | grep mnt`. If the drives are listed, everything is fine.

If you really get "target is busy" on `umount`, a program or terminal is using the drive. Close file-manager windows and shells whose current directory is inside the drive, then retry. To find the culprit:

```bash
sudo lsof +f -- /mnt/data1
```

## `findmnt /mnt/data1 /mnt/data2` prints nothing

**Cause:** `findmnt` accepts only **one** path at a time, so a two-path command prints nothing. It does not mean the drives are unmounted.

**Fix:** run it separately:

```bash
findmnt /mnt/data1
findmnt /mnt/data2
```

## Duplicate lines in `/etc/fstab`

If you edit fstab twice, you can end up with the same mount point listed twice (for example one line without `x-gvfs-show` and one with it). Systemd then has conflicting entries and may leave the drives unmounted.

**Fix:**

```bash
sudo nano /etc/fstab      # delete the duplicates with Ctrl+K, keep one line per mount point
grep mnt /etc/fstab       # confirm exactly one line per drive
sudo systemctl daemon-reload
sudo mount -a
```

## Drives do not appear in the file manager sidebar or "Devices and Locations"

Drives mounted via fstab under `/mnt` are treated as system mounts and hidden by GNOME. They are still fully usable.

Options:

- Open the path directly: `Ctrl+L`, then type `/mnt/data1`.
- Bookmark it: open the folder and press `Ctrl+D`.
- Add `x-gvfs-show` to the fstab options (see the [guide](01-step-by-step-guide.md#step-11-optional-show-the-drives-in-the-file-manager)), reload, and reopen the file manager.

## "Permission denied" when writing

The mount point is owned by `root`.

```bash
sudo chown -R $USER:$USER /mnt/data1 /mnt/data2
```

## System does not boot after editing fstab

1. At the GRUB menu, boot into recovery mode, or use a live USB.
2. Mount the root filesystem read-write and restore the backup: `cp /etc/fstab.bak /etc/fstab`.
3. Reboot.

Using `nofail` on data drives makes this very unlikely.

## The new drive is not listed by `lsblk`

- Check power and SATA cables at both ends, and try a different SATA port.
- Check the BIOS/UEFI storage settings (the port must be enabled).
- Run `sudo dmesg | grep -i -E "ata|sd"` for detection errors.
- Run `sudo fdisk -l` to list all disks.

## `mkfs.ext4` warns that the device contains an existing filesystem

For a brand-new drive this should not happen. If it does, **stop** and re-check that you have the right device. Do not add `-F` (force) unless you are certain the drive is the correct one and its contents are expendable.

## Drive letters changed after reboot

This is why fstab uses UUIDs. Confirm the mapping with:

```bash
lsblk -o NAME,SIZE,SERIAL,UUID,MOUNTPOINT
```

## Checking drive health later

```bash
sudo smartctl -H /dev/sdb          # quick health verdict
sudo smartctl -a /dev/sdb          # full SMART report
sudo smartctl -t short /dev/sdb    # run a short self-test
```
