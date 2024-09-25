---
title: "Remote Debugging with gdb and qemu"
date: 2024-09-21T15:59:49-07:00
draft: true
---

## Starting qemu with debug options

Use `-s` and `-S`[^1]

```shell
$ qemu-system-x86_64 -s -S binary.bin
```

## Remote debugging with gef

By default, gdb is listening at `localhost:1234`

```console
gef➤  gef-remote localhost 1234
```

## Remote debugging a boot-loader 

For compatibility reasons, x86 processors execute in [real mode](https://wiki.osdev.org/Real_Mode), which is a legacy 16bit mode.

After connecting to the remote target, the follwoing should be run in gdb:

```console
gef➤  set architecture i8086
```

## References
- https://www.qemu.org/docs/master/system/gdb.html
- https://wiki.osdev.org/Real_Mode
- https://stackoverflow.com/questions/14242958/debugging-bootloader-with-gdb-in-qemu
