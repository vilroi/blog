---
title: "Kea, Raw Sockets, and Icmp"
date: 2024-05-04T08:26:17-07:00
draft: true
toc: false
images:
tags:
  - linux
  - networking
---

The other day I was taking a look at [kea](https://kea.readthedocs.io/en/latest/index.html), the open-source DHCP server from ISC for my home network.

I installed kea on my gateway, made the minimal configurations necessary to get started. 

After that I and checked my laptop, and  confirmed that it had successfully been assigned an IP address from the range I had configured. 

Neat.

I was about to move on to further skim through the documentation, but then had a realization:

> "Wait a minute, I haven't enabled port 67 on my gateway yet. How is it accepting DHCP requests?"

Reconfirming my firewall rules with iptables, indeed port 67 had not been enabled, and my default policy had been set to DROP as intended.

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

More specifically, kea uses a raw socket with AF_PACKET. 

Packet sockets allow a program to send and receive layer 2 frames without the kernel's intervention.

That is, when data is received on the network interface it is handed to the user space process without being processed by the kernel.

![](https://www.opensourceforu.com/wp-content/uploads/2015/03/Figure-11-1-350x108.jpg)

This explains why `kea` had been able to respond to DHCP requests despite it not being allowed in `iptables`; the packets simply by-pass the kernel where the packet headers are inspected.

In order to demonstrate this idea, I wrote an ICMP "echo server" which listens for ICMP Echo Requests and replies to them. 

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