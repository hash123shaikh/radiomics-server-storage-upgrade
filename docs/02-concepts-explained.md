# Concepts Explained

Why does a brand-new drive need all these steps? A new drive is like an empty plot of land. The computer cannot store files on it until the space is marked out and a filing system is built. This takes three stages: **partition**, **format**, **mount**. A fourth piece, **fstab**, makes the result permanent.

## 1. Partitioning

A **partition table** is a small map at the start of the drive that tells the computer how the space is divided.

- **GPT** (GUID Partition Table) is the modern standard. It supports drives larger than 2 TB and is required on UEFI systems.
- `parted ... mklabel gpt` writes the table.
- `mkpart primary ext4 0% 100%` creates one partition covering the full drive. The device becomes `sdb` (whole disk) plus `sdb1` (the partition).

Without a partition table, the operating system sees only raw, unusable space.

## 2. Formatting (creating a filesystem)

A **filesystem** is the structure that records where each file lives, its name, size, permissions and timestamps.

- **ext4** is the default, mature and reliable Linux filesystem.
- `mkfs.ext4` builds it inside the partition.
- `-L data1` gives it a label.
- `-m 0` removes the default 5% reserved space. That reserve exists so a full system drive can still operate; a pure data drive does not need it.

Formatting is the step that **destroys any existing data** on the target partition. Only run it on drives you have confirmed are empty and new.

## 3. Mounting

Linux has no `D:` or `E:` drive letters. Every storage device is attached to a **folder** inside a single directory tree.

- The folder is called a **mount point** (for example `/mnt/data1`).
- `mount /dev/sdb1 /mnt/data1` attaches the drive to that folder. Anything saved in `/mnt/data1` is then stored on the new drive.
- A plain `mount` command lasts only until reboot.

If a drive is not mounted, its mount-point folder is just an empty folder on the system drive, and files written there would silently fill the system drive instead.

## 4. `/etc/fstab`

`/etc/fstab` ("file systems table") is read at every boot to decide which drives to mount and where.

Each line has six fields:

```
<file system>  <mount point>  <type>  <options>  <dump>  <pass>
UUID=...       /mnt/data1     ext4    defaults,nofail  0  2
```

- **file system**: which device, identified by UUID.
- **mount point**: where to attach it.
- **type**: filesystem type.
- **options**: `defaults` is the normal set; `nofail` prevents a boot failure if the drive is absent.
- **dump**: legacy backup flag, use `0`.
- **pass**: order of filesystem checks at boot. `1` for the root filesystem, `2` for others, `0` to skip.

## 5. UUIDs

A **UUID** is a unique identifier stored in the filesystem. Device names like `sdb1` are assigned in the order the kernel detects drives and **can change** after a reboot, a BIOS change, or when drives are added or removed. A UUID never changes, so using it in fstab keeps the right drive attached to the right folder.

Find UUIDs with:

```bash
sudo blkid
```

## 6. Device naming cheat sheet

| Name | Meaning |
|---|---|
| `sda`, `sdb`, `sdc` | SATA/SCSI disks, in detection order |
| `sda1`, `sdb1` | Partition 1 on that disk |
| `nvme0n1`, `nvme0n1p1` | NVMe disk and its partition (note the `p`) |
| `loopN` | Snap package images (ignore these) |
| `sr0` | Optical drive |
| `sdd` with 0B size | Often an empty card reader (ignore) |

## 7. Does the system drive overflow into the new drive automatically?

No. Each drive is a separate filesystem. When the system drive fills up, writes to it fail; nothing moves to the new drive. You must decide what lives where (see [Using the new storage](06-using-the-new-storage.md)).
