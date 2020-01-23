# citrix-check
citrix_check.sh version 0.1.0 by Taneli Kaivola / Nixu

```
Usage: citrix_check.sh [options] -t TARGET
    TARGET is a mounted vmdk with filesystems mounted in flash/ and var/

general options:
    -x              print everything the script does
execution options:
    --no-triage     do not run triage
    --no-config     do not run config checks
    --no-forensics  do not run forensics checks
    -l or --live    run tests in live system (excludes some noisy bash logs)
    -a or --all     run very slow checks
path options:
    -no-var         skip running tests on var
    -no-flash       skip running tests on flash
    -var=path       set relative path to be user for var
    -flash=path     set relative path to be user for flash
```

Full example for running a check (most of this requires root):

```
qemu-nbd -r -c /dev/nbd1 netscaler.vmdk
mkdir -p target/{flash,var}
mount -t ufs -o ro,ufstype=ufs2 /dev/nbd1p1 target/flash
mount -t ufs -o ro,ufstype=ufs2 /dev/nbd1p8 target/var
./citrix_check.sh -t target | tee report.md
pandoc -f markdown -o report.html report.md
umount target/flash
umount target/var
qemu-nbd -d /dev/nbd1
rmdir target/{flash,var}
```

