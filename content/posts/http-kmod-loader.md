---
title: "Loading Kernel Module From the Network"
date: 2024-05-12T13:23:15-07:00
slug: 2024-05-12-http-kmod-loader
type: posts
draft: true
categories:
  - default
tags:
  - linux
  - networking
---

# Intro

The first time I found out about [init_module(2)](https://linux.die.net/man/2/init_module), what stood out to me was the fact that it took a buffer containing the data, rather than a file path as its argument.

Looking at this, I had the following thought: would it be possible to fetch a kernel module from the network, store it in a buffer, and use that buffer as an argument to init_module(2)? This way, I would be able to load it without ever touching disk.

To demonstrate this idea, I wrote the a tool to do just that.
