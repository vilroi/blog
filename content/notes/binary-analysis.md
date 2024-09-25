---
title: "Binary Analysis"
date: 2024-09-22T08:17:44-07:00
draft: true
---

## objdump

Disassembling x86 binaries with `objdump`, outputting the result in intel syntax[^1]:

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

[^1]: https://stackoverflow.com/questions/14290879/disassembling-a-flat-binary-file-using-objdump
