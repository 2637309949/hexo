---
title: GO指针高级运算
date: 2019-08-28 01:49:19
categories: 
- Go
tags:
    - pointer
---

通常我们在GO中只会用到指针的取值和赋值，因为涉及到GC问题，GO本身不建议对指针进行运算，不过笔者第一门语言就是C，所以这里，整理一下如何在GO中使用指针运算。
<!-- more -->

## C指针

### 指针变量
指针取值和赋值

```c
#include <stdio.h>
int main(void)
{
    int a=10;
    int *p = &a;
    *p = 89;

    printf("变量值a=%d a=%d\n", a,*p);
    printf("指针地址p=%p p=%p\n",p,&a);
    return 0;
}
```
```sh
[Running] cd "/home/double/Work/GO/demo/" && gcc test.c -o test && "/home/double/Work/GO/demo/"test
变量值a=89 a=89
指针地址p=0x7fff3fe62a64 p=0x7fff3fe62a64
指针地址p=0x7fff3fe62a64 p=0x7fff3fe62a64
```

### 指针运算
指针运算与偏移

```c
#include <stdio.h>

int main(){
    #pragma pack(1)
        typedef struct{
            int age;
            char name[10];
        }Profile;
        printf("%d\n",sizeof(Profile));
        Profile p = {18,"double"};
        Profile* pa = &p;
        int* age        = (int *)(void *)pa;
        char* name        = (char *)(void *)(age+1);
        printf("%d ",*age);
        printf("%s", name);
        return 0;
    #pragma pack()
}
```
```sh
[Running] cd "/home/double/Work/GO/demo/" && gcc test.c -o test && "/home/double/Work/GO/demo/"test
14
18 double
```
结构体内不能采用字符自动对齐，必须要用#pragma pack编译制导将对齐最小字符设为1才行，否则
偏移取值运算不能到达指定的位置

## GO指针
在GO中我们通过unsafe.Pointer拿到指针的地址，相当于（*void）, 而运算时我们需要转成uintptr才能运算(QAQ)。

### unsafe.Pointer
Pointer represents a pointer to an arbitrary type. There are four special operations available for type Pointer that are not available for other types:

- A pointer value of any type can be converted to a Pointer.
- A Pointer can be converted to a pointer value of any type.
- A uintptr can be converted to a Pointer.
- A Pointer can be converted to a uintptr.

```go
package main

import (
	"fmt"
	"unsafe"
)

// Profile defined Profile
type Profile struct {
	Name string
	Age  int64
}

func main() {
	n := Profile{Name: "double", Age: 1}
	nPointer := unsafe.Pointer(&n)

	fmt.Println(nPointer)
	fmt.Println(uintptr(nPointer))
}
```

### uintptr

Converting a Pointer to a uintptr produces the memory address of the value pointed at, as an integer. The usual use for such a uintptr is to print it.
A uintptr is an integer, not a reference. Converting a Pointer to a uintptr creates an integer value with no pointer semantics. Even if a uintptr holds the address of some object, the garbage collector will not update that uintptr's value if the object moves, nor will that uintptr keep the object from being reclaimed.

```go
package main

import (
	"fmt"
	"unsafe"
)

// Profile defined Profile
type Profile struct {
	Name string
	Age  int64
}

func main() {
	n := Profile{Name: "double", Age: 1}
    nPointer := unsafe.Pointer(&n)
    
	fmt.Println(nPointer)
	fmt.Println(uintptr(nPointer))
}
```
需要注意的是uintptr是指针地址，我们不要把它作为变量去储存，否者GC没法知道引用计数。

### unsafe.Sizeof
获取指针内存大小
```go
e := unsafe.Pointer(uintptr(unsafe.Pointer(&x[0])) + i*unsafe.Sizeof(x[0]))
```

### unsafe.Offsetof

获取指针内存偏移量
```go
package main

import (
	"fmt"
	"unsafe"
)

// Profile defined Profile
type Profile struct {
	Name string
	Age  int64
}

func main() {
	n := Profile{Name: "double", Age: 18}
	nPointer := unsafe.Pointer(&n)
	name := (*string)(unsafe.Pointer(nPointer))
	age := (*int64)(unsafe.Pointer(uintptr(unsafe.Pointer(name)) + unsafe.Offsetof(n.Age)))
	// or
	age2 := (*int64)(unsafe.Pointer(uintptr(nPointer) + unsafe.Offsetof(n.Age)))

	fmt.Println(*name)
	fmt.Println(*age)
	fmt.Println(*age2)
}
```
```go
[Running] go run "/home/double/Work/GO/demo/main.go"
double
18
18
```

## GO指针进阶

### 指针与reflect

我们还可以在反射里使用指针操作
```go
p := (*int)(unsafe.Pointer(reflect.ValueOf(new(int)).Pointer()))
```

```go
package main

import (
	"fmt"
	"reflect"
	"unsafe"
)

// Profile defined Profile
type Profile struct {
	Name string
	Age  int64
}

func main() {
	s := (*Profile)(nil)
	t := reflect.TypeOf(s).Elem()

	v := reflect.New(t)
	sp := (*Profile)(unsafe.Pointer(v.Pointer()))
	sp.Age = 3

	fmt.Println(sp)
}
```

```sh
[Running] go run "/home/double/Work/GO/demo/main.go"
&{ 3}
```

### 指针与类型转换

如果存储布局一样，而且内存空间前者大于后者。我们可以转换类型。
```go
func float642uin64(f float64) uint64 {
	return *(*uint64)(unsafe.Pointer(&f))
}
```

### 指针与地址偏移

使用首地址+偏移的方式，巧妙的访问数据。
```go
// equivalent to f := unsafe.Pointer(&s.f)
f := unsafe.Pointer(uintptr(unsafe.Pointer(&s)) + unsafe.Offsetof(s.f))

// equivalent to e := unsafe.Pointer(&x[i])
e := unsafe.Pointer(uintptr(unsafe.Pointer(&x[0])) + i*unsafe.Sizeof(x[0]))
```

### 访问私有变量

如果你能计算出指针大小和偏移，那么我们可以越过GO的某些限制，如访问私有变量
```go
package p

// Profile defined Profile
type Profile struct {
	Name string
	age  int64
}
```

```go
package main

import (
	"fmt"
	"unsafe"

	"github.com/2637309949/demo/p"
)

func main() {
	n := p.Profile{Name: "double"}
	nPointer := unsafe.Pointer(&n)
	name := (*string)(unsafe.Pointer(nPointer))
	age := (*int64)(unsafe.Pointer(uintptr(unsafe.Pointer(name)) + unsafe.Sizeof(n.Name)))
	*age = 18
	fmt.Println(*name)
	fmt.Println(*age)

	fmt.Println(n)
}
```
```sh
[Running] go run "/home/double/Work/K11/GO/demo/main.go"
double
18
{double 18}
```