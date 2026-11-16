# Safety Checklist

The goal: **never touch the existing drive or its data**. Only three kinds of commands are destructive here: `parted mklabel`, `mkfs.*` and `mdadm --create`. Each one affects only the device you name.

## Before you start

- [ ] **Back up** anything irreplaceable. Adding drives is low-risk, but a typo in a device name is not.
- [ ] Note the **serial numbers** of the new drives (from the label on each drive, BIOS, or purchase paperwork).
- [ ] Note the model and serial of the **existing** drive, so you can recognise it.

## Before every destructive command

Run:

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINT /dev/sdX
```

Proceed only if **all** of these are true for the target:

- [ ] The serial matches one of the new drives.
- [ ] It has **no partitions** underneath it.
- [ ] `FSTYPE` is empty.
- [ ] `MOUNTPOINT` is empty.
- [ ] It is **not** the drive that holds `/` or `/boot/efi`.

If the drive shows `/` or `/boot/efi`, or the serial of the existing drive, **stop**.

## Why device names are risky

Names such as `sdb` and `sdc` are assigned at boot in detection order. After you power the machine off and add or move drives, the letters can shift. A drive that was `sdb` yesterday could be `sda` today. Always re-check with `lsblk` **right before** formatting, and do not rely on notes from an earlier session.

## Safer paths (optional)

Use stable, serial-based device paths instead of `sdX`:

```bash
ls -l /dev/disk/by-id/ | grep <serial>
```

Then pass the by-id path to `parted` and `mkfs`. These links always point to the same physical drive.

## Protecting `/etc/fstab`

A bad fstab line is the one change that can cause boot problems (it does not erase data).

- Always `sudo cp /etc/fstab /etc/fstab.bak` first.
- Use `nofail` on data drives.
- Test with `sudo mount -a` **before** rebooting.
- Keep each mount point listed only once.
- To undo: `sudo cp /etc/fstab.bak /etc/fstab`.

## RAID is not a backup

Even with RAID 1, deleting a file deletes it from both drives, and a power surge, fire or ransomware can affect both. Keep an independent copy of critical data, ideally off the machine.

## Quick backup example

Once the new drive is mounted, you can copy important folders onto it (reading from the original and writing to the new drive does not alter the original):

```bash
rsync -avh --progress /path/to/important/ /mnt/data1/backup/important/
```

Compare sizes afterwards:

```bash
du -sh /path/to/important /mnt/data1/backup/important
```
