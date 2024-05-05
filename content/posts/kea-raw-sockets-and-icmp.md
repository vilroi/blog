---
title: "Kea, Raw Sockets, and ICMP"
date: 2024-05-04T08:26:17-07:00
draft: false
toc: false
images:
tags:
  - linux
  - networking
---

The other day I was taking a look at [kea](https://kea.readthedocs.io/en/latest/index.html), an open-source DHCP server from ISC for my home network.

I installed it on my gateway, made the minimal initial configurations, and fired it up.

Then I checked my laptop and confirmed that it had successfully been assigned an IP address from the range I had allocated. 

So far so good.

I was about to proceed to checking out the other parts of the configuration and the documentation.

However, I had a sudden realization:

> "Wait a minute, I haven't enabled port 67 on my gateway's firewall. How is it accepting DHCP requests?"

All of my machines are configured so that it drops any ingress traffic by default.

My gateway is no exception to this. Sure enough port 67 had not been enabled when I confirmed my firewall rules with iptables.

What gives?

Then I remembered reading something about raw sockets in the config file.

From `kea-dhcp4.conf`:
```console
// Kea DHCPv4 server by default listens using raw sockets. This ensures
// all packets, including those sent by directly connected clients
// that don't have IPv4 address yet, are received. However, if your
// traffic is always relayed, it is often better to use regular
// UDP sockets. If you want to do that, uncomment this line:
// "dhcp-socket-type": "udp"
```

### \#\# Raw Sockets

Specifically, kea uses a raw socket with the address family set to AF_PACKET. 

Packet sockets allow a process to send and receive layer 2 frames without the kernel's intervention.

That is, when data is received on the network interface it is handed to the user space process without being processed by the kernel.

![](https://www.opensourceforu.com/wp-content/uploads/2015/03/Figure-11-1-350x108.jpg)

This explains why kea had been able to respond to DHCP requests despite it being disabled in iptables; the packets simply by-pass the kernel where the packet headers would be inspected.

In order to demonstrate this idea, I wrote an ICMP "echo server"[^1] which listens for ICMP Echo Requests and replies to them. 

The following is an excerpt from the code. The full source code can be found [here](https://github.com/vilroi/lab/tree/main/raw/icmp_echo_server).

```c
#include <stdio.h>
#include <stdlib.h>

#include <sys/socket.h>
#include <arpa/inet.h>
#include <net/ethernet.h>

#include "packet.h"
#include "error.h"
#include "utils.h"

int 
main(void)
{
	int			sockfd;
	packetbuf_t	recvbuf, sendbuf;

	if ((sockfd = socket(AF_PACKET, SOCK_DGRAM, htons(ETH_P_ALL))) == -1)
		ERR_EXIT("socket failed");

	init_packetbuf(&recvbuf);
	init_packetbuf(&sendbuf);

	while (1) {
		receive_packet(sockfd, &recvbuf);
		craft_packet(&sendbuf, &recvbuf);
		send_packet(sockfd, &sendbuf);
	}

	exit(EXIT_SUCCESS);
}
```

The following is a short demo:

{{<video src="/static/icmp_server.webm" type="video/webm" preload="auto">}}

### \#\# Interesting ICMP Behaviors
Here are some interesting things I encountered while working on the above.

#### \#\#\# Truncated
This happened when I tried to send an icmp packet with no data (only the IP header and ICMP header).

```console
[vilr0i@cyberia ~]$ ping 192.168.122.141
PING 192.168.122.141 (192.168.122.141) 56(84) bytes of data.
8 bytes from 192.168.122.141: icmp_seq=1 ttl=64 (truncated)
8 bytes from 192.168.122.141: icmp_seq=2 ttl=64 (truncated)
8 bytes from 192.168.122.141: icmp_seq=3 ttl=64 (truncated)
8 bytes from 192.168.122.141: icmp_seq=4 ttl=64 (truncated)
8 bytes from 192.168.122.141: icmp_seq=5 ttl=64 (truncated)
^C
```

#### \#\#\# Wrong Data Byte
The following occurred when the data portion for the icmp message had been filled with zeros.

```console
[vilr0i@cyberia ~]$ ping 192.168.122.141
PING 192.168.122.141 (192.168.122.141) 56(84) bytes of data.
64 bytes from 192.168.122.141: icmp_seq=1 ttl=64 time=1714850526716 ms
wrong data byte #16 should be 0x10 but was 0x0
#16     0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
#48     0 0 0 0 0 0 0 0 
64 bytes from 192.168.122.141: icmp_seq=2 ttl=64 time=1714850527717 ms
wrong data byte #16 should be 0x10 but was 0x0
#16     0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
#48     0 0 0 0 0 0 0 0 
```

### \#\# Resources and Further Reading

- [raw(7)](https://www.man7.org/linux/man-pages/man7/raw.7.html)
- [packet(7)](https://www.man7.org/linux/man-pages/man7/packet.7.html)
- [C Language Examples of IPv4 and IPv6 Raw Sockets for Linux](https://pdbuchan.com/rawsock/rawsock.html)
- [RFC 792: Internet Control Message Protocol](https://www.rfc-editor.org/rfc/rfc792)
- [Implementation of IP Checksum Calculation in Go](https://github.com/google/netstack/blob/55fcc16cd0eb/tcpip/header/checksum.go#L52)

[^1]: Yes, the notion of an ICMP Echo Server doesn't make much sense. ICMP is usually handled in layer 3 (the kernel, etc), so if a device receives an ICMP Echo request, a Reply is made independent to any user-space processes. In fact, if you run the program I wrote on a machine where ICMP is **not** disabled, it results in the client receiving a duplicate Reply.
