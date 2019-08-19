---
title: GO协程高并发设计
date: 2019-08-18 21:04:08
categories: 
- Go
tags:
    - promise
---
各种语言基本都会有一个提高程序并发处理的解决方式，这里我们以实际为背景，展开GO routines和 Go queue的设计，其中，GO语言中是通过信道通信的方式来完成协程之间协作，那么在实际应用中我们如何优雅而高效地设计协程程序呢，接下我们通过实际应用中的毛刺来剖析routines及实践最佳方案。
<!-- more -->

## 任务flow
![](/images/go-promise/ideal.png)
在main协程中我们有一个任务包含协程1，协程2，协程3，而各自又包含多个子协程完成整个任务，我们试一试用go协程结合信道通信以及另一种解决方案。

### 协程开发

新建任务1
```go
func task1(ret uint) (chan uint, chan uint, chan uint) {
	var wg sync.WaitGroup
	task11 := make(chan uint, 1)
	task12 := make(chan uint, 1)
	task13 := make(chan uint, 1)
	wg.Add(3)
	go func(c chan uint) {
		time.Sleep(time.Duration(2 * time.Second))
		fmt.Printf("task1-1 %v \n", ret)
		task11 <- 11
		wg.Done()
	}(task11)
	go func(c chan uint) {
		time.Sleep(time.Duration(2 * time.Second))
		fmt.Printf("task1-2 %v \n", ret)
		task12 <- 12
		wg.Done()
	}(task12)
	go func(c chan uint) {
		time.Sleep(time.Duration(2 * time.Second))
		fmt.Printf("task1-3 %v \n", ret)
		task13 <- 13
		wg.Done()
	}(task13)
	wg.Wait()
	return task11, task12, task13
}
```

新建任务2
```go
func task2(ret1 uint, ret2 uint, ret3 uint) (uint, uint) {
	var wg sync.WaitGroup
	task21 := make(chan uint, 1)
	task22 := make(chan uint, 1)
	wg.Add(2)
	go func(c chan uint) {
		time.Sleep(time.Duration(2 * time.Second))
		fmt.Printf("task2-1 %v %v %v \n", ret1, ret2, ret3)
		task21 <- 21
		wg.Done()
	}(task21)
	go func(c chan uint) {
		time.Sleep(time.Duration(2 * time.Second))
		fmt.Printf("task2-2  %v %v %v \n", ret1, ret2, ret3)
		task22 <- 22
		wg.Done()
	}(task22)
	wg.Wait()
	return <-task21, <-task22
}
```

新建任务3
```go
func task3(ret1 uint, ret2 uint) uint {
	var wg sync.WaitGroup
	task31 := make(chan uint, 1)
	wg.Add(1)
	go func(c chan uint) {
		time.Sleep(time.Duration(2 * time.Second))
		fmt.Printf("task3-1 %v %v \n", ret1, ret2)
		task31 <- 31
		wg.Done()
	}(task31)
	return <-task31
}
```

最终调用
```go
package main

import (
	"fmt"
	"sync"
	"time"
)
func main() {
	ret := <-func(task chan uint) chan uint {
		p1, p2, p3 := task1(1)
        defer func() {
            close(p1)
            close(p2)
            close(p3)
        }()
        task <- task3(task2(<-p1, <-p2, <-p3))
		return task
	}(make(chan uint, 1))
	fmt.Printf("task %v \n", ret)
}
```

最后控制台打印
```sh
task1-1 1 
task1-3 1 
task1-2 1 
task2-1 11 12 13 
task2-2  11 12 13 
task3-1 21 22 
task 31 
```

整个流程写起来有种回到C时代，其实我们在设计程序时基本把信道通信作为一个协程的返回结果载体，在实际中我们并不关心这个交互的过程，如上面我们花了很多代码去控制整个设计的流程，如chan的读写，WaitGroup的等待结果。那么我们可以尝试把整个流程的控制包装一次，如上面的chan交互，WaitGroup子任务同步，我们可以屏蔽不管的，我们只关心开启一个协程最终返回一个结果以及一个可选的error。

```go
package main

import "fmt"

type mess struct {
	emit chan interface{}
	ret  interface{}
	err  error
}

func (m *mess) get() (interface{}, error) {
	defer func() {
		close(m.emit)
	}()
	if m.err != nil {
		return nil, m.err
	}
	return <-m.emit, nil
}

func asyncFunc(funk func() (interface{}, error)) *mess {
	m := &mess{
		emit: make(chan interface{}, 1),
	}
	go func() {
		ret, err := funk()
		if err != nil {
			m.err = err
		} else {
			m.emit <- ret
		}
	}()
	return m
}

func main() {
	as := asyncFunc(func() (interface{}, error) {
		return 100, nil
	})
	fmt.Println(as.get())
}
```
在上面我们把整个异步的控制放在asyncFunc去完成了，屏蔽了其中交互。

### Promsie
在上面的应用设计中我们很容易发现一个核心点，所有的任务最终是一个串联和并联的组合，在并联中我们使用异步，串联（也就是等待上一个任务的结果才开始）我们使用同步。我们换一种方式thenable开发
下面我们使用
[https://github.com/fanliao/go-promise](https://github.com/fanliao/go-promise)  

```go
package main

import (
	"fmt"

	"github.com/fanliao/go-promise"
)

func main() {
	p := promise.NewPromise()
	go func() {
		// task1
		if task1, err := promise.WhenAll(func() (r interface{}, err error) {
			return 11, nil
		}, func() (r interface{}, err error) {
			return 12, nil
		}, func() (r interface{}, err error) {
			return 13, nil
		}).Get(); err == nil {
			// task2
			if task2, err := promise.WhenAll(func() (r interface{}, err error) {
				fmt.Printf("%v", task1)
				return 21, nil
			}, func() (r interface{}, err error) {
				return 22, nil
			}).Get(); err == nil {
				// task3
				if task3, err := promise.WhenAll(func() (r interface{}, err error) {
					fmt.Printf("%v", task2)
					return 31, nil
				}).Get(); err == nil {
					p.Resolve(task3)
				}
			}
		}
	}()
	ret, err := p.Get()
	fmt.Printf("%v %v", ret, err)
}
```
整个设计相对之前的方式简洁很多，编程的函数签名也很明确。
## 协程flow
![](/images/go-promise/flow.png)

在理想的设计中，我们不要让任务去`等`子任务完成，而是类似事件模型设计一样，让子任务来`通知`紧接着才开始自已的任务。而且需要非常明确那些任务是串关系，那些是并关系

### 任务拆分
### 任务组合


## 消息队列
![](/images/go-promise/queue.svg)

无论我们程序怎么高效率地处理各种任务，但是CPU以及物理机总有一个计算瓶颈的，不管是纵向增加物理机配置还是横向添加物理机数量。那么我们需要在物理机子可运算的范围之外添加消息队列。让服务计算从被动转主动的形式从而发挥最大的效率。

### 设计思路

### 最小化实现