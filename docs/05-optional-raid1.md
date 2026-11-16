# Optional: Mirror the Two New Drives (RAID 1)

Instead of using the two drives separately (about 7.2 TB total, no redundancy), you can mirror them with Linux software RAID (`mdadm`). You get **one** volume of about 3.6 TB that keeps working if a single drive fails.

> Do this **instead of** steps 3 to 7 in the [main guide](01-step-by-step-guide.md). Use only the two **new, empty** drives. **Never include the system drive.**

## Trade-offs

| | Two separate drives | RAID 1 mirror |
|---|---|---|
| Usable space | about 7.2 TB | about 3.6 TB |
| Survives one drive failure | No (lose that drive's data) | Yes |
| Protects against accidental deletion | No | **No** |
| Complexity | Low | Medium |

RAID is **not** a backup. Deleting a file deletes it from both drives.

## Setup

```bash
sudo apt install -y mdadm

# Create the mirror from the two NEW drives only
sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb /dev/sdc

# Watch the initial sync (can take hours on 4 TB drives; the array is usable meanwhile)
cat /proc/mdstat

# Create a filesystem and mount it
sudo mkfs.ext4 -m 0 -L data /dev/md0
sudo mkdir -p /mnt/data
sudo mount /dev/md0 /mnt/data

# Save the array definition so it assembles at boot
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
sudo update-initramfs -u
```

Add it to `/etc/fstab` by UUID:

```bash
sudo blkid /dev/md0
sudo cp /etc/fstab /etc/fstab.bak
sudo nano /etc/fstab
```

```
UUID=<uuid-of-md0>  /mnt/data  ext4  defaults,nofail  0  2
```

Test, then set ownership:

```bash
sudo mount -a
df -h | grep mnt
sudo chown -R $USER:$USER /mnt/data
```

## Monitoring and maintenance

```bash
cat /proc/mdstat                 # quick status
sudo mdadm --detail /dev/md0     # detailed status
```

An `[UU]` in `/proc/mdstat` means both drives are healthy; `[U_]` or `[_U]` means one has dropped out.

Replace a failed drive:

```bash
sudo mdadm /dev/md0 --fail /dev/sdX --remove /dev/sdX
# physically replace the drive, then:
sudo mdadm /dev/md0 --add /dev/sdY
```

Consider enabling email alerts by setting `MAILADDR` in `/etc/mdadm/mdadm.conf`.
