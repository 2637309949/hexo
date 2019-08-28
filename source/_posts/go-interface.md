---
title: Interface引起的`血案`，底层实现挖掘
date: 2019-08-28 15:58:31
categories: 
- Go
tags:
	- interface
---
之前我们指针运算中指出reflect创建的数据未经断言也就是interface{}，那么它的sizeof与真实类型是不对等。所以我决定它挖掘一下interface{}究竟做了什么。

<!-- more -->

## 用法

go语言基于C而创建的，底层没有所谓的*void泛指针，那么interface{}的出现就是为了满足这一情况的：躲开静态检测，让类型检测在运行期间运行。

我们可以定义
```go
type Stringer interface {
    String() string
}
```

使用时进行断言
```go
func ToString(any interface{}) string {
    if v, ok := any.(Stringer); ok {
        return v.String()
    }
    switch v := any.(type) {
    case int:
        return strconv.Itoa(v)
    case float:
        return strconv.Ftoa(v, 'g', -1)
    }
    return "???"
}
```
这一切的类型断言都在运行期间完成，所以要判断断言是否成功才去使用，否则将会panic。


## 接口值

程序语言领域对方法的处理通常在两个步骤完成：为所有静态调用方法准备一张表（如在C ++和Java中），或者在每次调用时进行方法查找（如Smalltalk及其许多模仿者，包括JavaScript和Python）和添加花哨的缓存以使该调用有效。Go位于两者之间：它有方法表，但在运行时计算它们。

我们继续使用上面的例子，再添加
```go
type Binary uint64

func (i Binary) String() string {
    return strconv.Uitob64(i.Get(), 2)
}

func (i Binary) Get() uint64 {
    return uint64(i)
}
```

然后把Binary转成Interface{}类型
```go
b := Binary(200)
s := Stringer(b) 
```

此时GO做了下面的功夫
![](/images/go-interface/gointer2.png)

接口值表示为双指针，指向存储在接口中的类型信息的指针和指向相关数据的指针。

接口值中的第一个指针指向的我们称之为接口表或itable（发音为i-table;在运行时源中，C实现名称为Itab）。itable从关于所涉及类型的一些元数据开始，然后成为函数指针的列表。请注意，itable对应于接口类型，而不是动态类型。就我们的例子而言，Stringer持有类型的itable Binary 列出了用于满足的方法Stringer，这只是String：Binary其他方法（Get）在itable中没有出现。

接口值中的第二个字指向实际数据，在这种情况下是一个副本b。由于var s Stringer = b产生副本的原因相同，分配会复制b而不是指向 ：如果稍后更改， 并且应该具有原始值，而不是新值。存储在接口中的值可能是任意大的，但只有一个字专用于将值保存在接口结构中，因此赋值在堆上分配一块内存并将指针记录在单字槽中。（当值恰好适合插槽时，有一个明显的优化;我们稍后会讨论它。）

要检查接口值是否包含特定类型（如上面的类型switch），Go编译器会生成与C表达式等效的代码，s.tab->type以获取类型指针并根据所需类型进行检查。如果类型匹配，则可以通过引用来复制该值s.data。

要调用s.String()，Go编译器会生成与C表达式等效的代码 s.tab->fun[0](s.data)：它从itable调用相应的函数指针，将接口值的数据字作为函数的第一个（在此示例中，仅）参数传递。如果你运行，你可以看到这个代码8g -S x.go（详见本文的底部）。请注意，itable中的函数从接口值的第二个字传递32位指针，而不是它指向的64位值。通常，接口调用站点不知道该单词的含义，也不知道它指向的数据量。相反，接口代码安排itable中的函数指针期望存储在接口值中的32位表示。因此，此示例中的函数指针(*Binary).String 不是Binary.String。


上面的例子是只有一种方法的接口。具有更多方法的界面将在itable底部的fun列表中包含更多条目。

## 计算Itable

现在我们知道itables的样子了，但它们来自哪里？Go的动态类型转换意味着编译器或链接器预先计算所有可能的itables是不合理的：有太多（接口类型，具体类型）对，并且大多数都不需要。相反，编译器为每个具体类型生成类型描述结构，如Binaryor int或func(map[int]string)。在其他元数据中，类型描述结构包含由该类型实现的方法的列表。类似地，编译器为每个接口类型生成（不同的）类型描述结构Stringer; 它也包含一个方法列表。接口运行时通过查找具体类型的方法表中接口类型的方法表中列出的每个方法来计算itable。运行时在生成它之后缓存itable，因此这种对应只需要计算一次。

在我们的简单示例中，方法表 Stringer有一个方法，而表 Binary有两个方法。通常，可能有接口类型的ni方法和具体类型的nt方法。找到从接口方法到具体方法的映射的明显搜索将花费O（ni × nt）时间，但我们可以做得更好。通过对两个方法表进行排序并同时处理它们，我们可以在O（ni + nt）时间内构建映射。


## 内存优化

上述实现所使用的空间可以以两种互补的方式进行优化。

首先，如果涉及的接口类型为空 - 它没有方法 - 那么除了将指针保持为原始类型之外，itable没有用处。在这种情况下，可以删除itable，并且值可以直接指向类型：

![](/images/go-interface/gointer3.png)


接口类型是否具有方法是静态属性 - 或者源代码中的类型是 interface{}或者是 - interace{ methods... }编译器知道程序在那个点中正在使用哪个类型。
其次，如果与接口值关联的值可以适合单个字节，则无需引入间接或堆的分配。如果我们定义 Binary32为类似Binary 但实现为a uint32，则可以通过将实际值保存在第二个字节中来存储在接口值中：

![](/images/go-interface/gointer4.png)

实际值是指向还是内联取决于类型的大小。编译器安排类型的方法表中列出的函数（将其复制到itables中）以使用传入的单词执行正确的操作。如果接收器类型适合单字节，则直接使用; 如果没有，它被解除引用。图表显示了这一点：在Binary上面的版本中，itable中的方法是 (*Binary).String，而在 Binary32示例中，itable中的方法Binary32.String 不是(*Binary32).String。

当然，保持word-sized大小（或更小）值的空接口可以利用这两种优化：

![](/images/go-interface/gointer5.png)


## 方法查找性能

Smalltalk及其后面的许多动态系统每次调用方法时都会执行方法查找。为了提高速度，许多实现在每个调用站点使用简单的单项缓存，通常在指令流本身。在多线程程序中，必须小心管理这些高速缓存，因为多个线程可以同时位于同一个调用站点。即使一旦避免了比赛，缓存最终也会成为内存争用的来源。

因为Go具有静态类型的提示以与动态方法查找一起使用，所以它可以将查找从调用站点移回到值存储在接口中的点。例如，请考虑以下代码段：
```go
var any interface{}  // initialized elsewhere
s := any.(Stringer)  // dynamic conversion
for i := 0; i < 100; i++ {
    fmt.Println(s.String())
}
```
在Go中，在第2行的赋值期间计算（或在缓存中找到）itable; s.String()在第4行执行的调用的调度 是一对内存提取和一个间接调用指令。

相比之下，使用Smalltalk（或JavaScript，或Python等）这样的动态语言实现此程序将在第4行进行方法查找，这在循环中重复了不必要的工作。前面提到的缓存使得它比它可能更便宜，但它仍然比单个间接调用指令更昂贵。


## 附录
```go
package main

import (
 "fmt"
 "strconv"
)

type Stringer interface {
 String() string
}

type Binary uint64

func (i Binary) String() string {
 return strconv.Uitob64(i.Get(), 2)
}

func (i Binary) Get() uint64 {
 return uint64(i)
}

func main() {
 b := Binary(200)
 s := Stringer(b)
 fmt.Println(s.String())
}
```



参考链接
[https://research.swtch.com/interfaces](https://research.swtch.com/interfaces)
