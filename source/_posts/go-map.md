---
title: GO MAP的底层实现
date: 2019-08-27 11:48:42
categories: 
- Go
tags:
	- map
---

在任何语言中，数据的存储，查找，删除都是关键核心的部分，所以用户无需关注，但是学习如何处理这些东西往往可以更高层次的提升自已的数据思维（其实也就是复习大学的数据结构QAQ），这里主要整理出go中 map 的赋值、删除、查询、扩容的具体执行过程。
<!-- more -->

## 常见的查找方式
Go 语言中MAP采用的是哈希查找表，并且使用链表解决哈希冲突。我们先看看什么是哈希查找表和搜索树

### 哈希查找表（Hash table）
哈希查找是通过计算数据元素的存储地址进行查找的一种方法。O(1)的查找，即所谓的秒杀。哈希查找的本质是先将数据映射成它的哈希值。哈希查找的核心是构造一个哈希函数，它将原来直观、整洁的数据映射为看上去似乎是随机的一些整数。

哈希查找的操作步骤：

- 用给定的哈希函数构造哈希表；

- 根据选择的冲突处理方法解决地址冲突；

- 在哈希表的基础上执行哈希查找。

其实常用的做哈希的手法有“五种”：

第一种：”直接定址法“。

很容易理解，key=Value+C；这个“C"是常量。Value+C其实就是一个简单的哈希函数。

第二种：“除法取余法”。

很容易理解， key=value%C;解释同上。

第三种：“数字分析法”。

这种蛮有意思，比如有一组value1=112233，value2=112633，value3=119033，

针对这样的数我们分析数中间两个数比较波动，其他数不变。那么我们取key的值就可以是

key1=22,key2=26,key3=90。

第四种：“平方取中法”。此处忽略，见名识意。

第五种：“折叠法”。

这种蛮有意思,比如value=135790，要求key是2位数的散列值。那么我们将value变为13+57+90=160，然后去掉高位“1”,此时key=60，哈哈，这就是他们的哈希关系，这样做的目的就是key与每一位value都相关，来做到“散列地址”尽可能分散的目地。

影响哈希查找效率的一个重要因素是哈希函数本身。当两个不同的数据元素的哈希值相同时，就会发生冲突。为减少发生冲突的可能性，哈希函数应该将数据尽可能分散地映射到哈希表的每一个表项中。


解决冲突的方法有以下两种：　　

(1)   开放地址法　　

如果两个数据元素的哈希值相同，则在哈希表中为后插入的数据元素另外选择一个表项。当程序查找哈希表时，如果没有在第一个对应的哈希表项中找到符合查找要求的数据元素，程序就会继续往后查找，直到找到一个符合查找要求的数据元素，或者遇到一个空的表项。　　

(2)   链地址法

将哈希值相同的数据元素存放在一个链表中，在查找哈希表的过程中，当查找到这个链表时，必须采用线性查找方法。


### 搜索树（Search tree）
搜索树法一般采用自平衡搜索树，包括：AVL 树，红黑树。

红黑树和AVL树一样都对插入时间、删除时间和查找时间提供了最好可能的最坏情况担保。这不只是使它们在时间敏感的应用，如实时应用（real time application）中有价值，而且使它们有在提供最坏情况担保的其他数据结构中作为基础模板的价值；例如，在计算几何中使用的很多数据结构都可以基于红黑树实现。

红黑树在函数式编程中也特别有用，在这里它们是最常用的持久数据结构（persistent data structure）之一，它们用来构造关联数组和集合，每次插入、删除之后它们能保持为以前的版本。除了 O(log n)的时间之外，红黑树的持久版本对每次插入或删除需要O(log n)的空间。

红黑树是2-3-4树的一种等同。换句话说，对于每个2-3-4树，都存在至少一个数据元素是同样次序的红黑树。在2-3-4树上的插入和删除操作也等同于在红黑树中颜色翻转和旋转。这使得2-3-4树成为理解红黑树背后的逻辑的重要工具，这也是很多介绍算法的教科书在红黑树之前介绍2-3-4树的原因，尽管2-3-4树在实践中不经常使用。

红黑树相对于AVL树来说，牺牲了部分平衡性以换取插入/删除操作时少量的旋转操作，整体来说性能要优于AVL树。
#### AVL树
数据结构教学里的一课，这里不再搬概念的东西，可以看看下面链接。
[https://baike.baidu.com/item/AVL%E6%A0%91](https://baike.baidu.com/item/AVL%E6%A0%91)

核心：任何节点的两个子树的高度最大差别为1，增加和删除可能需要通过一次或多次树旋转来重新平衡这个树


#### 红黑树
还记得我大学学习的数据结构的课本没有红黑树这一节，自已百度补的。
[https://zh.wikipedia.org/wiki/%E7%BA%A2%E9%BB%91%E6%A0%91](https://zh.wikipedia.org/wiki/%E7%BA%A2%E9%BB%91%E6%A0%91)

核心：红黑树是每个节点都带有颜色属性的二叉查找树，颜色为红色或黑色。在二叉查找树强制一般要求以外，对于任何有效的红黑树我们增加了如下的额外要求：

- 节点是红色或黑色。
- 根是黑色。
- 所有叶子都是黑色（叶子是NIL节点）。
- 每个红色节点必须有两个黑色的子节点。（从每个叶子到根的所有路径上不能有两个连续的红色节点。）
- 从任一节点到其每个叶子的所有简单路径都包含相同数目的黑色节点。

## Go Map
Go 语言中MAP采用的是哈希查找表，哈希查找表用一个哈希函数将 key 分配到不同的桶。这样，开销主要在哈希函数的计算以及数组的常数访问时间。在很多场景下，哈希查找表的性能很高。

### 内存模型
[https://github.com/golang/go/blob/master/src/runtime/map.go](https://github.com/golang/go/blob/master/src/runtime/map.go)

```go
// A header for a Go map.
type hmap struct {
	// Note: the format of the hmap is also encoded in cmd/compile/internal/gc/reflect.go.
	// Make sure this stays in sync with the compiler's definition.
	count     int // # live cells == size of map.  Must be first (used by len() builtin)
	flags     uint8
	B         uint8  // log_2 of # of buckets (can hold up to loadFactor * 2^B items)
	noverflow uint16 // approximate number of overflow buckets; see incrnoverflow for details
	hash0     uint32 // hash seed

	buckets    unsafe.Pointer // array of 2^B Buckets. may be nil if count==0.
	oldbuckets unsafe.Pointer // previous bucket array of half the size, non-nil only when growing
	nevacuate  uintptr        // progress counter for evacuation (buckets less than this have been evacuated)

	extra *mapextra // optional fields
}
```

其中buckets的结构
```go
// A bucket for a Go map.
type bmap struct {
	// tophash generally contains the top byte of the hash value
	// for each key in this bucket. If tophash[0] < minTopHash,
	// tophash[0] is a bucket evacuation state instead.
	tophash [bucketCnt]uint8
	// Followed by bucketCnt keys and then bucketCnt elems.
	// NOTE: packing all the keys together and then all the elems together makes the
	// code a bit more complicated than alternating key/elem/key/elem/... but it allows
	// us to eliminate padding which would be needed for, e.g., map[int64]int8.
	// Followed by an overflow pointer.
}
```

```go
// mapextra holds fields that are not present on all maps.
type mapextra struct {
	// If both key and elem do not contain pointers and are inline, then we mark bucket
	// type as containing no pointers. This avoids scanning such maps.
	// However, bmap.overflow is a pointer. In order to keep overflow buckets
	// alive, we store pointers to all overflow buckets in hmap.extra.overflow and hmap.extra.oldoverflow.
	// overflow and oldoverflow are only used if key and elem do not contain pointers.
	// overflow contains overflow buckets for hmap.buckets.
	// oldoverflow contains overflow buckets for hmap.oldbuckets.
	// The indirection allows to store a pointer to the slice in hiter.
	overflow    *[]*bmap
	oldoverflow *[]*bmap

	// nextOverflow holds a pointer to a free overflow bucket.
	nextOverflow *bmap
}
```

### 哈希函数
在hash时我们看到源码使用的是
```go
alg.hash(key, uintptr(h.hash0))
```

定位到：
[https://github.com/golang/go/blob/master/src/runtime/alg.go](https://github.com/golang/go/blob/master/src/runtime/alg.go)

我们可以查看不同的hash实现：

```go
// typeAlg is also copied/used in reflect/type.go.
// keep them in sync.
type typeAlg struct {
	// function for hashing objects of this type
	// (ptr to object, seed) -> hash
	hash func(unsafe.Pointer, uintptr) uintptr
	// function for comparing objects of this type
	// (ptr to object A, ptr to object B) -> ==?
	equal func(unsafe.Pointer, unsafe.Pointer) bool
}
```

其中如果系统支持AES，那么会开启AES

```go
func initAlgAES() {
	if GOOS == "aix" {
		// runtime.algarray is immutable on AIX: see cmd/link/internal/ld/xcoff.go
		return
	}
	useAeshash = true
	algarray[alg_MEM32].hash = aeshash32
	algarray[alg_MEM64].hash = aeshash64
	algarray[alg_STRING].hash = aeshashstr
	// Initialize with random data so hash collisions will be hard to engineer.
	getRandomData(aeskeysched[:])
}
```
### 创建函数

```go
// makemap implements Go map creation for make(map[k]v, hint).
// If the compiler has determined that the map or the first bucket
// can be created on the stack, h and/or bucket may be non-nil.
// If h != nil, the map can be created directly in h.
// If h.buckets != nil, bucket pointed to can be used as the first bucket.
func makemap(t *maptype, hint int, h *hmap) *hmap {
	mem, overflow := math.MulUintptr(uintptr(hint), t.bucket.size)
	if overflow || mem > maxAlloc {
		hint = 0
	}

	// initialize Hmap
	if h == nil {
		h = new(hmap)
	}
	h.hash0 = fastrand()

	// Find the size parameter B which will hold the requested # of elements.
	// For hint < 0 overLoadFactor returns false since hint < bucketCnt.
	B := uint8(0)
	for overLoadFactor(hint, B) {
		B++
	}
	h.B = B

	// allocate initial hash table
	// if B == 0, the buckets field is allocated lazily later (in mapassign)
	// If hint is large zeroing this memory could take a while.
	if h.B != 0 {
		var nextOverflow *bmap
		h.buckets, nextOverflow = makeBucketArray(t, h.B, nil)
		if nextOverflow != nil {
			h.extra = new(mapextra)
			h.extra.nextOverflow = nextOverflow
		}
	}

	return h
}
```

通过源码看到map创建时回去申请buckets，其中.B是可以申请的大小
```go
h.buckets, nextOverflow = makeBucketArray(t, h.B, nil)
```

我们看到如果桶的大小B不够存放的话会B++直到超过8，如果超过8，多余的会存在nextOverflow中。
```go
// overLoadFactor reports whether count items placed in 1<<B buckets is over loadFactor.
func overLoadFactor(count int, B uint8) bool {
	return count > bucketCnt && uintptr(count) > loadFactorNum*(bucketShift(B)/loadFactorDen)
}
```

### 查找操作

[https://github.com/golang/go/blob/master/src/runtime/map.go](https://github.com/golang/go/blob/master/src/runtime/map.go)

```go

// mapaccess1 returns a pointer to h[key].  Never returns nil, instead
// it will return a reference to the zero object for the elem type if
// the key is not in the map.
// NOTE: The returned pointer may keep the whole map live, so don't
// hold onto it for very long.
func mapaccess1(t *maptype, h *hmap, key unsafe.Pointer) unsafe.Pointer {
	if raceenabled && h != nil {
		callerpc := getcallerpc()
		pc := funcPC(mapaccess1)
		racereadpc(unsafe.Pointer(h), callerpc, pc)
		raceReadObjectPC(t.key, key, callerpc, pc)
	}
	if msanenabled && h != nil {
		msanread(key, t.key.size)
	}
	if h == nil || h.count == 0 {
		if t.hashMightPanic() {
			t.key.alg.hash(key, 0) // see issue 23734
		}
		return unsafe.Pointer(&zeroVal[0])
	}
	if h.flags&hashWriting != 0 {
		throw("concurrent map read and map write")
	}
	alg := t.key.alg
	hash := alg.hash(key, uintptr(h.hash0))
	m := bucketMask(h.B)
	b := (*bmap)(add(h.buckets, (hash&m)*uintptr(t.bucketsize)))
	if c := h.oldbuckets; c != nil {
		if !h.sameSizeGrow() {
			// There used to be half as many buckets; mask down one more power of two.
			m >>= 1
		}
		oldb := (*bmap)(add(c, (hash&m)*uintptr(t.bucketsize)))
		if !evacuated(oldb) {
			b = oldb
		}
	}
	top := tophash(hash)
bucketloop:
	for ; b != nil; b = b.overflow(t) {
		for i := uintptr(0); i < bucketCnt; i++ {
			if b.tophash[i] != top {
				if b.tophash[i] == emptyRest {
					break bucketloop
				}
				continue
			}
			k := add(unsafe.Pointer(b), dataOffset+i*uintptr(t.keysize))
			if t.indirectkey() {
				k = *((*unsafe.Pointer)(k))
			}
			if alg.equal(key, k) {
				e := add(unsafe.Pointer(b), dataOffset+bucketCnt*uintptr(t.keysize)+i*uintptr(t.elemsize))
				if t.indirectelem() {
					e = *((*unsafe.Pointer)(e))
				}
				return e
			}
		}
	}
	return unsafe.Pointer(&zeroVal[0])
}
```

通过源码我们可以看到，先对key hash，接着找到key所在的桶（每桶最大可以存储8个`bucketCnt = 1 << bucketCntBits`,在源码66行可以看到。）
```go
hash := alg.hash(key, uintptr(h.hash0))
m := bucketMask(h.B)
b := (*bmap)(unsafe.Pointer(uintptr(h.buckets) + (hash&m)*uintptr(t.bucketsize)))
```

找到对应桶后，对桶内的数据进行hash对比`alg.equal(key, k)`
```go
for ; b != nil; b = b.overflow(t) {
    for i := uintptr(0); i < bucketCnt; i++ {
        if b.tophash[i] != top {
            if b.tophash[i] == emptyRest {
                break bucketloop
            }
            continue
        }
        k := add(unsafe.Pointer(b), dataOffset+i*uintptr(t.keysize))
        if t.indirectkey() {
            k = *((*unsafe.Pointer)(k))
        }
        if alg.equal(key, k) {
            e := add(unsafe.Pointer(b), dataOffset+bucketCnt*uintptr(t.keysize)+i*uintptr(t.elemsize))
            if t.indirectelem() {
                e = *((*unsafe.Pointer)(e))
            }
            return e, true
        }
    }
}
```

其实在go Mao查找中我们看到源码是对应两个方式的，也就是_,ok := map 和 _ := map 的对应实现。
```go
func mapaccess1(t *maptype, h *hmap, key unsafe.Pointer) unsafe.Pointer
func mapaccess2(t *maptype, h *hmap, key unsafe.Pointer) (unsafe.Pointer, bool)
```

### 扩容操作
在添加ele时我们看看其中扩容的逻辑

[https://github.com/golang/go/blob/master/src/runtime/map.go](https://github.com/golang/go/blob/master/src/runtime/map.go)

```go
// Like mapaccess, but allocates a slot for the key if it is not present in the map.
func mapassign(t *maptype, h *hmap, key unsafe.Pointer) unsafe.Pointer {
	if h == nil {
		panic(plainError("assignment to entry in nil map"))
	}
	if raceenabled {
		callerpc := getcallerpc()
		pc := funcPC(mapassign)
		racewritepc(unsafe.Pointer(h), callerpc, pc)
		raceReadObjectPC(t.key, key, callerpc, pc)
	}
	if msanenabled {
		msanread(key, t.key.size)
	}
	if h.flags&hashWriting != 0 {
		throw("concurrent map writes")
	}
	alg := t.key.alg
	hash := alg.hash(key, uintptr(h.hash0))

	// Set hashWriting after calling alg.hash, since alg.hash may panic,
	// in which case we have not actually done a write.
	h.flags ^= hashWriting

	if h.buckets == nil {
		h.buckets = newobject(t.bucket) // newarray(t.bucket, 1)
	}

again:
	bucket := hash & bucketMask(h.B)
	if h.growing() {
		growWork(t, h, bucket)
	}
	b := (*bmap)(unsafe.Pointer(uintptr(h.buckets) + bucket*uintptr(t.bucketsize)))
	top := tophash(hash)

	var inserti *uint8
	var insertk unsafe.Pointer
	var elem unsafe.Pointer
bucketloop:
	for {
		for i := uintptr(0); i < bucketCnt; i++ {
			if b.tophash[i] != top {
				if isEmpty(b.tophash[i]) && inserti == nil {
					inserti = &b.tophash[i]
					insertk = add(unsafe.Pointer(b), dataOffset+i*uintptr(t.keysize))
					elem = add(unsafe.Pointer(b), dataOffset+bucketCnt*uintptr(t.keysize)+i*uintptr(t.elemsize))
				}
				if b.tophash[i] == emptyRest {
					break bucketloop
				}
				continue
			}
			k := add(unsafe.Pointer(b), dataOffset+i*uintptr(t.keysize))
			if t.indirectkey() {
				k = *((*unsafe.Pointer)(k))
			}
			if !alg.equal(key, k) {
				continue
			}
			// already have a mapping for key. Update it.
			if t.needkeyupdate() {
				typedmemmove(t.key, k, key)
			}
			elem = add(unsafe.Pointer(b), dataOffset+bucketCnt*uintptr(t.keysize)+i*uintptr(t.elemsize))
			goto done
		}
		ovf := b.overflow(t)
		if ovf == nil {
			break
		}
		b = ovf
	}

	// Did not find mapping for key. Allocate new cell & add entry.

	// If we hit the max load factor or we have too many overflow buckets,
	// and we're not already in the middle of growing, start growing.
	if !h.growing() && (overLoadFactor(h.count+1, h.B) || tooManyOverflowBuckets(h.noverflow, h.B)) {
		hashGrow(t, h)
		goto again // Growing the table invalidates everything, so try again
	}

	if inserti == nil {
		// all current buckets are full, allocate a new one.
		newb := h.newoverflow(t, b)
		inserti = &newb.tophash[0]
		insertk = add(unsafe.Pointer(newb), dataOffset)
		elem = add(insertk, bucketCnt*uintptr(t.keysize))
	}

	// store new key/elem at insert position
	if t.indirectkey() {
		kmem := newobject(t.key)
		*(*unsafe.Pointer)(insertk) = kmem
		insertk = kmem
	}
	if t.indirectelem() {
		vmem := newobject(t.elem)
		*(*unsafe.Pointer)(elem) = vmem
	}
	typedmemmove(t.key, insertk, key)
	*inserti = top
	h.count++

done:
	if h.flags&hashWriting == 0 {
		throw("concurrent map writes")
	}
	h.flags &^= hashWriting
	if t.indirectelem() {
		elem = *((*unsafe.Pointer)(elem))
	}
	return elem
}
```

源码有三块again:，bucketloop，done，从其中的逻辑中我们可以看到，在bucketloop中将elem放进buckets中，如果大小超了就会触发扩容。
```go
// If we hit the max load factor or we have too many overflow buckets,
// and we're not already in the middle of growing, start growing.
if !h.growing() && (overLoadFactor(h.count+1, h.B) || tooManyOverflowBuckets(h.noverflow, h.B)) {
    hashGrow(t, h)
    goto again // Growing the table invalidates everything, so try again
}
```


### 遍历操作
关于 map 先是调用 mapiterinit 函数初始化迭代器，然后循环调用 mapiternext 函数进行 map 迭代。

[https://github.com/golang/go/blob/master/src/runtime/map.go](https://github.com/golang/go/blob/master/src/runtime/map.go)

```go
func mapiterinit(t *maptype, h *hmap, it *hiter)
```

### 赋值操作

以上扩容机制
[https://github.com/golang/go/blob/master/src/runtime/map.go](https://github.com/golang/go/blob/master/src/runtime/map.go)

```go
func mapassign(t *maptype, h *hmap, key unsafe.Pointer) unsafe.Pointer
```

### 删除操作

对应函数
[https://github.com/golang/go/blob/master/src/runtime/map.go](https://github.com/golang/go/blob/master/src/runtime/map.go)


```go
func mapdelete(t *maptype, h *hmap, key unsafe.Pointer)
```

其中逻辑我们可以看源码，包括引用回收

```go
// Only clear key if there are pointers in it.
if t.indirectkey() {
    *(*unsafe.Pointer)(k) = nil
} else if t.key.ptrdata != 0 {
    memclrHasPointers(k, t.key.size)
}
```

## 其他

### 线程安全

map 并不是一个线程安全的数据结构。同时读写一个 map 是未定义的行为，如果被检测到，会直接 panic。

一般而言，这可以通过读写锁来解决：sync.RWMutex。

读之前调用 RLock() 函数，读完之后调用 RUnlock() 函数解锁；写之前调用 Lock() 函数，写完之后，调用 Unlock() 解锁。

通过sync，我们可以实现一个安全的Map

```go
package maps

import "sync"

// SafeMap defined SafeMap
type SafeMap struct {
	m map[string]interface{}
	l *sync.RWMutex
}

// Set defined Set
func (s *SafeMap) Set(key string, value interface{}) {
	s.l.Lock()
	defer s.l.Unlock()
	s.m[key] = value
}

// Get defined Get
func (s *SafeMap) Get(key string) interface{} {
	s.l.RLock()
	defer s.l.RUnlock()
	return s.m[key]
}

// ALL defined ALL
func (s *SafeMap) ALL() map[string]interface{} {
	s.l.RLock()
	defer s.l.RUnlock()
	return s.m
}

// NewSafeMap defined SafeMap
func NewSafeMap() *SafeMap {
	return &SafeMap{l: new(sync.RWMutex), m: make(map[string]interface{})}
}
```

### Key类型

官方指导：
As mentioned earlier, map keys may be of any type that is comparable. The language spec defines this precisely, but in short, comparable types are boolean, numeric, string, pointer, channel, and interface types, and structs or arrays that contain only those types. Notably absent from the list are slices, maps, and functions; these types cannot be compared using ==, and may not be used as map keys.

尤其使用struct作为key，我们可以实现多维度的map
```go
type Key struct {
    Path, Country string
}
hits := make(map[Key]int)
```

```go
hits[Key{"/", "vn"}]++
```

参考链接
[https://blog.csdn.net/xiaoping8411/article/details/7706376](https://blog.csdn.net/xiaoping8411/article/details/7706376)
[https://blog.golang.org/go-maps-in-action](https://blog.golang.org/go-maps-in-action)
