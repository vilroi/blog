---
title: "ffmpeg Cheat Sheet"
date: 2024-09-21T15:59:48-07:00
draft: true
---

## Format Conversion 

Example: from mkv to webm

```console
$ ffmpeg -i input.mkv output.webm
```

## Screen Capture

Example: Output screen to `.mkv`

```console
$ ffmpeg -f x11grab -i :0.0 out.mkv
```

## Trimming 

Cut out starting from 5sec to 48sec

```console
$ ffmpeg -i input.mp4 -ss 00:00:04 -to 00:00:48 -c:v copy -c:a copy output1.mp4
```

## Getting Video Info

```console
$ ffprobe video.webm
```

## Re-sizing a video

```console
$ ffmpeg -i input.webm -vf scale="720:480" output.webm
```

## Links
- https://shotstack.io/learn/use-ffmpeg-to-trim-video/
