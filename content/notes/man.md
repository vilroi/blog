---
title: "Man Pages"
date: 2024-09-21T15:59:48-07:00
draft: true
---

## Loading the Output of man(1) into vim(1)

```console
$ man 2 open | vim -
```

## Loading man pages into a vim tab

```console
:tabnew
:read ! man 7 packet
```
