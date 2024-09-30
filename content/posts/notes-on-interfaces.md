---
title: "Notes on Go Interfaces"
date: 2024-05-30T09:31:45-07:00
slug: 2024-05-30-notes-on-interfaces
type: posts
draft: false
categories:
  - default
tags:
  - go
  - binary
---

An `interface` in Go is an abstract type used to categorize discrete types based on the actions it is able to take (the methods it implements). 
More concretely, an interface is a data type represented as a set of function definitions.
Any type which implements the methods defined in the set can be treated as that interface.

- if type *x* implements methods *A()* and *B()* defined in interface *a*, then *x* can be treated as an *a*
- if type *y* also implements methods *A()* and *B()* defined in interface *a*, then *y* can also be treated as an *a*
- while *x* and *y* are distinct types, they can both be treated as type *a*

As an example, consider the types `net.HardwareAddr` and `netip.Addr`. 
Since both of these types implement the `String()` method, according to the definition of the `fmt.Stringer` interface, both of these types can be treated as a `fmt.Stringer`.

Thus, something like the following is possible:

```go
package main

import (
	"fmt"
	"net"
)

func main() {
	ifaces, err := net.Interfaces()
	check(err)

	for _, iface := range ifaces {
		fmt.Println(iface.Name)

		printStringer(iface.HardwareAddr)   // iface.Hardware{}

		addrs, err := iface.Addrs()
		check(err)

		for _, addr := range addrs {
			printStringer(addr)             // netip.Addr{}
		}

		fmt.Println()
	}
}

func printStringer(s fmt.Stringer) {        // pointless function
	fmt.Println(s)
}

func check(e error) {
	if e != nil {
		panic(e)
	}
}
```

...where `net.HardwareAddr` and `netip.Addr` are both passed into `printStringer()` as an argument of type `fmt.Stringer`.

## The 'interface\{\}'  Type

The `interface{}` type, also known as `any`, is defined as an interface with zero methods -- that is, an empty set.

Since all types in go by definition define zero or more methods, all types can be treated as an `interface{}`.

```go
package main

import (
	"fmt"
	"net"
)

func main() {
	s := "hello friend"

	macaddr, _ := net.ParseMAC("ff:ff:ff:ff:ff:ff")
	addrs := []net.HardwareAddr{macaddr}

	testFunc(s)
	testFunc(addrs)
}

func testFunc(v interface{}) {
	fmt.Printf("%T\n", v)
}
```

```console
$ go run empty.go
string
[]net.HardwareAddr
```


## Dissecting an 'interface\{\}'
How is it even possible to have a type which represents  all possible types?

How is it implemented, and how is it represented in memory?

[According to Russ Cox](https://research.swtch.com/interfaces), an interface is composed of two pointers. 

The first pointer points to a data structure which contains the type information, and the second pointer points to the actual data.

![](http://research.swtch.com/gointer2.png)

The empty interface (`interface{}`, or `any`), has a slightly different representation. Instead of having a pointer to an `abi.Itab` as its first word, it has a pointer to a `abi.Type`.

From [internal/abi/iface.go](https://github.com/golang/go/blob/master/src/internal/abi/iface.go):
```go
// EmptyInterface describes the layout of a "interface{}" or a "any."
// These are represented differently than non-empty interface, as the first
// word always points to an abi.Type.
type EmptyInterface struct {
    Type *Type
    Data unsafe.Pointer
}
```
We could confirm this by inspecting the memory layout of an `interface{}` using a debugger (in this case, `delve`), and dereferencing the pointers.

Here, I am inspecting the memory layout of a `string` passed as an `interface{}`:

```console
(dlv) c
> main.testFunc() ./empty.go:20 (hits goroutine(1):1 total:1) (PC: 0x4ac766)
    15:         testFunc(addrs)
    16: }
    17:
    18: func testFunc(v interface{}) {
    19:         addr := &v
=>  20:         fmt.Printf("%T, %p\n", v, addr)
    21: }
(dlv) print addr
(*interface {})(0xc000090500)
*interface {}(string) "hello friend"

(dlv) x -count 2 -size 8 0xc000090500   # dereferencing the address of the interface{}
0xc000090500:   0x00000000004b5a60   0x000000c0000904f0   

(dlv) x -count 8 -size 8 0x000000c0000904f0     # address of string, length 12 bytes
0xc0000904f0:   0x00000000004cddce   0x000000000000000c   0x00000000004b5a60   0x000000c0000904f0   0x0000000000000000   0x0000000000000000   0x0000000000000000   0x0000000000000000   

(dlv) x -count 12 0x00000000004cddce    # "hello friend"
0x4cddce:   0x68   0x65   0x6c   0x6c   0x6f   0x20   0x66   0x72   
0x4cddd6:   0x69   0x65   0x6e   0x64   
```

Confirming that the second word in an interface is a pointer to the underlying data type is relatively straight forward.

However, confirming the first word (which is the type information, represented as an `abi.Type`), is a bit more tricky.

From [internal/abi/type.go](https://github.com/golang/go/blob/master/src/internal/abi/type.go#L20):
```go
type Type struct {
	Size_       uintptr
	PtrBytes    uintptr // number of (prefix) bytes in the type that can contain pointers
	Hash        uint32  // hash of type; avoids computation in hash tables
	TFlag       TFlag   // extra type information flags
	Align_      uint8   // alignment of variable with this type
	FieldAlign_ uint8   // alignment of struct field with this type
	Kind_       uint8   // enumeration for C
	// function for comparing objects of this type
	// (ptr to object A, ptr to object B) -> ==?
	Equal func(unsafe.Pointer, unsafe.Pointer) bool
	// GCData stores the GC type data for the garbage collector.
	// If the KindGCProg bit is set in kind, GCData is a GC program.
	// Otherwise it is a ptrmask bitmap. See mbitmap.go for details.
	GCData    *byte
	Str       NameOff // string form
	PtrToThis TypeOff // type for pointer to this type, may be zero
}
```

```console
(dlv) x -count 64 0x00000000004b5a60
0x4b5a60:   0x10   0x00   0x00   0x00   0x00   0x00   0x00   0x00   // Size_
0x4b5a68:   0x08   0x00   0x00   0x00   0x00   0x00   0x00   0x00   // PtrBytes
0x4b5a70:   0xb8   0xcd   0x78   0x07   0x07   0x08   0x08   0x18   // Hash (4 bytes), Tlag(1 byte), Align_(1 byte), FieldAlign (1byte), Kind_(1byte)
0x4b5a78:   0x08   0x66   0x4d   0x00   0x00   0x00   0x00   0x00   // Equal
0x4b5a80:   0xe0   0xae   0x4d   0x00   0x00   0x00   0x00   0x00   // GCData
0x4b5a88:   0xd2   0x10   0x00   0x00   0x60   0x60   0x00   0x00   // Str, PtrToThis
0x4b5a90:   0x00   0x00   0x00   0x00   0x00   0x00   0x00   0x00   
0x4b5a98:   0x10   0x00   0x00   0x00   0x00   0x00   0x00   0x00   
```

We could deduce that we are indeed looking at the raw bytes of an `abi.Type` by cross-referencing a few fields. In this case, we will look at the following:
- Size_: 0x10 (16). Since a `string` is composed of a pointer to the data (8 bytes on x64) and the size field (8 bytes), this checks out.
- Kind_: 0x18 (24). The Kind_ field corresponds to the constant `abi.String`.
- Str: 0x10d2 (4306). The Str field is used to retrieve the string representation of a type. It contains an offset into [`moduledata.type`](https://github.com/golang/go/blob/master/src/runtime/symtab.go#L388), which in the case of an ELF file in linux contains the address of the `.rodata` section. We could dump the data in `.rodata` as follows:

```console
[vilroi@cyberia re-go]$ readelf -S __debug_bin3017757378 | grep rodata
  [ 3] .rodata           PROGBITS         00000000004ad000  000ad000

[vilroi@cyberia re-go]$ hexdump -C -s $((0x000ad000 + 0x10d2)) -n 32 __debug_bin3017757378 
000ae0d2  00 07 2a 73 74 72 69 6e  67 00 07 72 75 6e 74 69  |..*string..runti|
000ae0e2  6d 65 00 07 2a 75 69 6e  74 31 36 00 07 2a 75 69  |me..*uint16..*ui|
000ae0f2
```

## Further Reading and References
- https://jordanorelli.com/post/32665860244/how-to-use-interfaces-in-go
- https://research.swtch.com/interfaces
- https://cloud.google.com/blog/topics/threat-intelligence/golang-internals-symbol-recovery/
- [The code used to determine the value of `moduledata.type`](https://github.com/vilroi/lab/tree/main/gomoduledata)
