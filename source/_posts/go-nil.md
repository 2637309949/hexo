---
title: NIL知识点
date: 2019-09-16 10:15:45
categories: 
- Go
tags:
    - nil
---
如果不是有基础C或许你开始使用GO NIL不会有太多的疑问，否则会有很多的顾虑在里面，接下来我们来认识NIL。

<!-- more -->

## C语言
我们先从C认识一些基本的知识点，指针的初始化，空值和void指针，因为他们和nil有些相似的地方
### 指针初始化
可以用下列方式来初始化一个指针：
- 一个空指针常量。
- 指向相同类型的指针，或者指向具有较少限定符修饰的相同类型。
- 如果需初始化的指针不是函数指针，可以使用 void 指针进行初始化（同上，需初始化的指针可以是指向具有更多限定符类型的指针）。
```c
double x = 1.5;
char *cPtr = &x;          // 错误：类型不匹配；没有隐式转换
char *cPtr = (char *)&x;  // 正确：cPtr指向x的第一个字节
```

### 空指针
当把一个空指针常量转换为指针类型时，所得到的结果就是空指针（null pointer）。空指针常量（null pointer constant）是一个值为 0 的整数常量表达式，或者是一个 void* 类型的表达式。在头文件 stdlib.h、stdio.h 以及其他头文件中，宏 NULL 被定义为空指针常量。

```c
#include <stdio.h>
/* ... */
FILE *fp = fopen( "demo.txt", "r" );
if ( fp == NULL )           // 也可以被写成：if ( !fp )
{
  // 错误：无法打开demo.txt文件进行读取
}
```
如果有必要的话，空指针会被隐式地转换成其他指针类型，以进行赋值运算或者是进行 == 或 ！= 的比较运算。因此，上述例子不需要使用转型运算符。

### void 指针
指向 void 的指针，或者简称为 void 指针（void pointer），是类型为 void* 的指针。因为没有对象类型是 void，所以 void* 被称为万能指针类型。换句话说，void 指针可以代表任何对象的地址，但不代表该对象的类型。若想获取内存中的对象，必须先把 void 指针转换为合适的对象指针。

若想声明一个可以接收任何类型指针参数的函数，可以将所需的参数设定为指向 void 的指针。当调用这样的函数时，编译器会隐式地将对象指针参数转换成 void 指针。常见的例子如标准函数 memset（），它被声明在头文件 string.h 中，其原型如下：
```c
void *memset( void *s, int c, size_t n );
```

编译器会在必要的地方把 void 指针转换为对象指针。例如，在下面的语句中，函数 malloc（）返回一个 void 指针，它的值是已分配内存的语句块的地址。这样的赋值操作会把 void 指针转换成 int 指针：
```c
int *iPtr = malloc( 1000 * sizeof(int) );
```

## GO语言
### 零值
在GO语言中，如果我们不显示的对类型进行初始化，那么它会自动被初始化，以下是初始化后的情况。
```go
bool       --> false
numbers    --> 0
string     --> ""
pointers   --> nil
slices     --> nil
maps       --> nil
channels   --> nil
functions  --> nil
interfaces --> nil
```

对于结构体则根据结构体属性类型分别初始化
```go
type Person struct {
    AgeYears int
    Name     string
    Friend   []Person
}
var p Person //Person{o,"",nil}
```

### NIL类型
不像C中的void*, nil必须有类型才能使用，所以说nil!=nil（有点绕。。。），nil 没有默认类型, 尽管它有很多可能的类型. 编译器必须有足够的信息来从上下文中推导出 nil 的类型.
比如说
```go
package main
func main() {
	var str *string
	var i *int
	x := nil     // 错误: use of untyped nil
	if str == nil { // 用于判断时，编译器自动识别类型
	}
	if i == nil {  // 用于判断时，编译器自动识别类型
	}
	if str == i { // 错误: invalid operation: str == i (mismatched types *string and *int)
	}
}
```

在golang中的nil种类，同时不同种类所占用的空间大小也是不一样的。
- pointers
对于未初始化的指针，指向nil，亦可以说是什么都没有，类似C中的常量指针NULL。

- slices
对于slices，我们知道底层是由三个属性构成的结构体
```go
ptr *elem
len 0
cap 0
```
那么对于未初始化的slice ptr则指向nil
如果我们对未初始化的slice进行append，那么他会自动扩容。

- maps
底层指向内存空间的指针指向nil
```go
m := (map[string]string)(nil)
m["123"] = "123"  // 错误: assignment to entry in nil map 由于指向nil，所以不能直接错误
fmt.Println(len(m))
```

- channels
底层指向内存空间的指针指向nil
```go
var  c chan t 
<-c           // 永远阻塞
c <-x         // 永远阻塞
close(c)      // panic:  关闭一个nil通道
```

- functions
底层指向内存空间的指针指向nil

- interfaces
使用两个机器字节指针保存类型信息和方法表，所以有这种情况的存在。

```go
var p *Person          // *Person是空的
var s fmt.Stringer = p // Stringer(*Person, nil)
fmt.Println(s == nil)  // falses
```

在实际中我们可通过类型转换提供nil类型信息，如下面，初始化了一个*int变量，由于未使用取地址赋值运算，所以这个指针内容指向nil。
```go
a := (*int)(nil)
```

## NIL 用例

### Equal等值判断
最常见的用例就是判断一个变量是否为nil类型，这也是最基本的操作。
```go
if i == nil {  // 用于判断时，编译器自动识别类型
}
```
### NIL类型转换
其实只要给nil类型信息的情况下，我们可以将nil转成对应类型，不过要正常使用还是得通过初始化， 也就是编译器通过这个类型信息知道整个变量的内存空间排列。
```go
package main

import (
	"fmt"
	"reflect"
)

func main() {
	a := (*int)(nil)
	// 由于a存放的是NIL，我们不能直接运算，如*a = 12
	reflect.ValueOf(&a).Elem().Set(reflect.New(reflect.TypeOf(&a).Elem().Elem()))
	*a = 100
	fmt.Println(*a)
}
```
### NIL接口实现

interface{}类型的nil值是可以实现接口的，我们上面讲过一个interface{}内部是由两个指针构成的，指向类型信息和方法表，
```go
package main

import (
	"fmt"
)

type Summer interface {
    Sum() int 
}

type ints []int
func (i ints) Sum() int {
    fmt.Println(i == nil)
    s := 0
    for _,v  := range i {
        s += v
    }
    return s
}

func main() {
	var i ints
	var s Summer = i 
	fmt.Println(i == nil, s.Sum())
}
```

```sh
[Running] go run "/home/double/work/GO/demo/tempCodeRunnerFile.go"
true
true 0
```
参考链接
[http://c.biancheng.net/view/360.html](http://c.biancheng.net/view/360.html)
