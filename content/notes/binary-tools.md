---
title: "Binary Tools"
date: 2024-09-22T08:17:44-07:00
draft: false
tags:
  - notes
  - linux
  - binary
---

## objdump

Disassembling x86 binaries with `objdump`, outputting the result in intel syntax [^1]:

```console
$ objdump -D -Mintel <file>
```

Disassembling a flat binary:

```console
$ objdump -b binary -m i8086 -D -Mintel test.bin

test.bin:     file format binary


Disassembly of section .data:

00000000 <.data>:
   0:   b4 de                   mov    ah,0xde
   2:   b0 ad                   mov    al,0xad
   4:   b8 ff ff                mov    ax,0xffff

```

## objcopy
Extracting the contents of a specified section [^2]:
``` console
$ objcopy --dump-section .text=output.bin input.o
```

[^1]: https://stackoverflow.com/questions/14290879/disassembling-a-flat-binary-file-using-objdump
[^2]: https://stackoverflow.com/questions/3925075/how-to-extract-only-the-raw-contents-of-an-elf-section
