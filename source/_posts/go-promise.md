---
title: go-promise
date: 2019-08-18 21:04:08
categories: 
- Go
tags:
    - promise
---
go语言中是通过信道通信的方式来完成协程之间协作，那么在实际应用中我们如何优雅的处理信道通信呢，接下我们通过事件模型的思想来剖析。
<!-- more -->

## 理想中的异步处理
![](/images/go-promise/ideal.png)
在main协程中我们有一个任务包含协程1，协程2，协程3，而各自又包含多个子协程完成整个任务，我们试一试直接使用go的信道通信

### 协程裸开发
```go
package main

import (
	"fmt"
	"sync"
	"time"
)

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

func main() {
	ret := <-func(task chan uint) chan uint {
		p1, p2, p3 := task1(1)
		task <- task3(task2(<-p1, <-p2, <-p3))
		return task
	}(make(chan uint, 1))
	fmt.Printf("task %v \n", ret)
}
```

```sh
task1-1 1 
task1-3 1 
task1-2 1 
task2-1 11 12 13 
task2-2  11 12 13 
task3-1 21 22 
task 31 
```

整个流程写起来有种回到C时代，其实我们在设计程序时基本把信道通信作为一个协程的返回结果的载体，在实际中我们并不关心这个交互的过程。

### 使用Promsie方式
```go
package main

import (
	"fmt"

	"github.com/fanliao/go-promise"
)

func main() {
	task1, _ := promise.WhenAll(func() (r interface{}, err error) {
		return "ok1", nil
	}, func() (r interface{}, err error) {
		return "ok1", nil
	}, func() (r interface{}, err error) {
		return "ok1", nil
	}).Get()

	task2, _ := promise.WhenAll(func() (r interface{}, err error) {
		fmt.Printf("%v", task1)
		return "ok1", nil
	}, func() (r interface{}, err error) {
		return "ok1", nil
	}).Get()

	task3, _ := promise.WhenAll(func() (r interface{}, err error) {
		fmt.Printf("%v", task2)
		return "ok1", nil
	}).Get()

	fmt.Printf("%v", task3)
}
```

## 同步协程flow