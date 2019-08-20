---
title: GO协程高并发设计
date: 2019-08-18 21:04:08
categories: 
- Go
tags:
	- promise
	- concurrent
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
在应用设计中我们需要把一个大任务拆解成几个小任务，具体如何定义小，我们是从实际出发，尽可能提高各个小任务之间的高分离，这样就减少切换routines栈的代价
```go
func funk() {
	// task1
	go func(){
		// task11
		go func(){
		}()
		// task12
		go func(){
		}()
	}()
	// task2
	go func(){
		// task21
		go func(){
			// task211
			go func(){
			}()
		}()
	}()
}
```
### 任务组合
经过任务拆分后的程序跑在不同的routine中，最后以某种组合形式达成最终效果，
```go
func funk() {
	task1, task2 := make(chan int, 1), make(chan int, 1)
	// task1
	go func(){
		// task11
		go func(){
		}()
		// task12
		go func(){
		}()
		task1 <- 1
	}()
	// task2
	go func(){
		// task21
		go func(){
			// task211
			go func(){
			}()
		}()
		task2 <- 1
	}()
	<- task1
	<- task2
}
```

## 消息队列
![](/images/go-promise/queue.svg)

无论我们程序怎么高效率地处理各种任务，但是CPU以及物理机总有一个计算瓶颈的，不管是纵向增加物理机配置还是横向添加物理机数量。那么我们需要在物理机子可运算的范围之外添加消息队列。让服务计算从被动转主动的形式从而发挥最大的效率。

### 设计思路
![](/images/go-promise/event.png
)
如上图，我们在main函数中开启了多个任务，比如消化前端的某个表单提交，那么这个表单属于某个策略，这个策略是一个定时的事件循环，后台处理表单请求后立即把它转换成消息并加入该策略的消息队列中，在策略中我们配置可以同时运行几个任务（根据具体的情况设置）

### 最小化实现
上面分析了如何设计一个最小的mq实现，我们下面通过go的方式实现整个逻辑，该演示代码来自我的bulrush子模块，完整的代码可以前往我的github

#### 定时函数
定时函数用来，以一定的时间间隔去扫描存在的消息队列并取其中一个消化。
```go
func setInterval(what func(), delay time.Duration) chan bool {
	ticker := time.NewTicker(delay)
	quit := make(chan bool)
	go func() {
		for {
			select {
			case <-ticker.C:
				go what()
			case <-quit:
				ticker.Stop()
				return
			}
		}
	}()
	return quit
}
```

#### 执行函数
在执行函数中，我们开启不同的策略函数去处理各自的队列
```go
func (mq *MQ) startTactic() *MQ {
	funk.ForEach(mq.TypeTactic, func(tac TypeTactic) {
		timer := setInterval(func() {
			ctCount := tac.Tactic.CTCount
			ttype := tac.Type
			var exector []Exector
			if ttype == "" {
				exector = funk.Filter(mq.Exector, func(exe Exector) bool {
					return funk.Find(mq.TypeTactic, func(ttc TypeTactic) bool {
						return ttc.Type == exe.Type
					}) == nil
				}).([]Exector)
			} else {
				exector = funk.Filter(mq.Exector, func(exe Exector) bool {
					return exe.Type == ttype
				}).([]Exector)
			}
			funk.ForEach(exector, func(exec Exector) {
				handler := exec.Handler
				handlerType := exec.Type
				pTaskCount := mq.Model.Count(handlerType, PROCESSING)
				iTask := mq.Model.Find(handlerType, INIT)
				sort.Sort(sortByMsAt(iTask))
				if len(iTask) >= 1 {
					task := iTask[0]
					if pTaskCount < ctCount {
						err := mq.Model.Update(task, PROCESSING)
						if err != nil {
							mq.Model.Update(task, FAILED)
						} else {
							err := handler(task)
							if err != nil {
								mq.Model.Update(task, FAILED)
							} else {
								mq.Model.Update(task, SUCCEED)
							}
						}
					}
				}
			})
		}, time.Duration(tac.Tactic.Interval)*time.Second)
		mq.Interval = append(mq.Interval, timer)
	})
	return mq
}
```

#### 策略函数
我们可以手动添加不同的策略函数，策略规则。
```go
// AddTactics add Tactics to system
func (mq *MQ) AddTactics(tp string, tac Tactic) *MQ {
	typeTac := funk.Find(mq.TypeTactic, func(tc TypeTactic) bool {
		return tc.Type == tp
	})
	if typeTac != nil {
		rushLogger.Info("rewrite Tactic strategy %v", typeTac)
		typeOne := typeTac.(TypeTactic)
		typeOne.Tactic = tac
	} else {
		mq.TypeTactic = append(mq.TypeTactic, TypeTactic{
			Type:   tp,
			Tactic: tac,
		})
	}
	go mq.loop()
	return mq
}
```

#### 消息推送
后台将请求计算转成消息的形式推送给时间循环。
```go
// Push events
func (mq *MQ) Push(mess Message) {
	mess.CreatedAt = time.Now()
	mess.Status = INIT
	mq.Model.Save(mess)
}
```