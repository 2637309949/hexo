---
title: GO错误处理最佳实践
date: 2019-08-17 14:24:18
categories: 
- Go
tags:
    - error
---
如何优雅地处理错误，在整个系统或框架的设计中尤其重要，笔者在实际中经常看到很多程序代码对于错误的处理非常粗暴，也非常不友好。这样的处理风格对于系统而言是非常致命的。所以我们不能忽略错误处理，这里以go为例子来解析如何优雅处理错误和异常。
<!-- more -->

## Error类型

### 业务逻辑
业务上不予许的逻辑错误，比如A用户给B用户转10元，但是A用户只有1元。这是不允许的。
```go
func funk(num uint) error {
	if num < 10 {
		return errors.Wrap(&Error{Code: ErrTypeNumber}, "[func1] failed with error:")
	}
	return nil
}
```
### 程序逻辑
程序逻辑不允许的错误导致程序不能运行的bug，比如下面反射的set
```go
func funk(num uint)  {
	reflect.ValueOf(123).Set(reflect.ValueOf(123))
}
```
## 如何处理错误
处理错误的方式都是一样的，不管什么语言--冒泡传递，直到有可以处理该错误的应用层并消化该错误（自定义错误编码），否则我们通过友好的形式展示给用户（自定义错误信息）。
```go
func func1(num uint) error {
	if num < 10 {
		return errors.Wrap(&Error{Code: ErrTypeNumber}, "[func1] failed with error:")
	}
	return nil
}
```
```go
if err = func1(1); err != nil {
	if originalErr, ok := errors.Cause(err).(*Error); ok {
		fmt.Println("the original error coed was : ", originalErr.Code)
	} else {
		log.Printf("%v", err)
	}
}
```
## 如何处理异常
在实际应用中就算程序出现异常我们也不能让程序退出进程，通常情况下我们会进行一个全局的异常信息捕获，将捕获的信息通过某种途径告诉用户，如http返回，控制台或者消息弹窗。在go中我们通过defer，recovery来恢复程序的异常：
```go
func myApp() (err error) {
	defer func() {
		if ret := recover(); ret != nil {
		}
	}()
	return
}

```
仅有这些信息还是不够的，我们通常还需要发生异常信息的故障点和错误堆栈，这时我们可以通过runtime.Caller获取具体的堆栈信息：
```go
func stack(skip int) []byte {
	buf := new(bytes.Buffer)
	var lines [][]byte
	var lastFile string
	for i := skip; ; i++ {
		pc, file, line, ok := runtime.Caller(i)
		if !ok {
			break
		}
		fmt.Fprintf(buf, "%s:%d (0x%x)\n", file, line, pc)
		if file != lastFile {
			data, err := ioutil.ReadFile(file)
			if err != nil {
				continue
			}
			lines = bytes.Split(data, []byte{'\n'})
			lastFile = file
		}
		fmt.Fprintf(buf, "\t%s: %s\n", function(pc), source(lines, line))
	}
	return buf.Bytes()
}
```
那是不是所有的地方都要以这种形式捕获系统异常呢？其实不然，在实际应用中我们通常只会在两个地方使用这种恢复代码。
1. 主应用，也就是启动函数。
2. 业务苛求，如数据库的事务。
其他情况我们都统一交给启动函数的全局异常捕获。

## 自定义错误
### 错误编码
```go
const ErrTypeNumber = 1 << 10
type Error struct {
	Code uint
}
```
### 错误信息
仅仅错误编码是不足够的，我们还需要额外的信息来描述这种错误。go也提供了对应的方式，我们可以通过errors.Wrap包装错误信息
```go
errors.Wrap(&Error{Code: ErrTypeNumber}, "[func1] failed with error:")
```
相反，我们可以通过errors.Cause获取原本错误对象
```go
cus, ok := errors.Cause(err).(*Error);
cus.Code
```
### 工具函数
自定义错误有一个功能点是常用的，我们直接将他们包装成工具类。这样我们可以统一处理并省去重复代码。

#### 包装错误信息
```go
// ErrWith defined wrap error
func ErrWith(err *Error, msg string) error {
	return errors.Wrap(err, msg)
}
```

#### 装换错误对象
```go
// ErrOut defined unwrap error
func ErrOut(err error) (bulError *Error, ok bool) {
	bulError, ok = errors.Cause(err).(*Error)
	return
}
```

#### 获取错误信息数组
```go
// ErrMsgs defined split wrap msg
func ErrMsgs(err error) []string {
	return strings.Split(err.Error(), ":")
}
```

#### 获取错误编码
```go
// ErrCode defined return error code
func ErrCode(err error) (code uint64) {
	if bulErr, ok := ErrOut(err); ok {
		code = bulErr.Code
	}
	code = ErrNu.Code
	return
}
```

## 错误转换
不管是那个实现了error接口的错误，在传递错误时都是以error对象传递（不要以自定义错误对象直接传递），在错误需要被处理消化时，我们可以通过类型断言的形式把原始对象解包出来
```go
if err = func1(1); err != nil {
	if originalErr, ok := errors.Cause(err).(*Error); ok {
		fmt.Println("the original error coed was : ", originalErr.Code)
	} else {
		log.Printf("%v", err)
	}
}
```

## Example
我们来看一个完整的应用实例，下面我们模拟了两个错误，业务层面的和系统层面的，我们通过自定义错误以及异常恢复的形式优雅的处理这两个错误。
```go
package main

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"log"
	"runtime"
	"time"

	"github.com/pkg/errors"
)

var (
	dunno     = []byte("???")
	centerDot = []byte("路")
	dot       = []byte(".")
	slash     = []byte("/")
)

func stack(skip int) []byte {
	buf := new(bytes.Buffer)
	var lines [][]byte
	var lastFile string
	for i := skip; ; i++ { 
		pc, file, line, ok := runtime.Caller(i)
		if !ok {
			break
		}
		fmt.Fprintf(buf, "%s:%d (0x%x)\n", file, line, pc)
		if file != lastFile {
			data, err := ioutil.ReadFile(file)
			if err != nil {
				continue
			}
			lines = bytes.Split(data, []byte{'\n'})
			lastFile = file
		}
		fmt.Fprintf(buf, "\t%s: %s\n", function(pc), source(lines, line))
	}
	return buf.Bytes()
}

func source(lines [][]byte, n int) []byte {
	n--
	if n < 0 || n >= len(lines) {
		return dunno
	}
	return bytes.TrimSpace(lines[n])
}

func function(pc uintptr) []byte {
	fn := runtime.FuncForPC(pc)
	if fn == nil {
		return dunno
	}
	name := []byte(fn.Name())
	if lastSlash := bytes.LastIndex(name, slash); lastSlash >= 0 {
		name = name[lastSlash+1:]
	}
	if period := bytes.Index(name, dot); period >= 0 {
		name = name[period+1:]
	}
	name = bytes.Replace(name, centerDot, dot, -1)
	return name
}

func timeFormat(t time.Time) string {
	var timeString = t.Format("2006/01/02 - 15:04:05")
	return timeString
}

const ErrTypeNumber = 1 << 10

type Error struct {
	Code uint
}

func (c *Error) Error() string {
	return fmt.Sprintf("Failed with code %v", c.Code)
}

// 模拟程序异常
func func2(num uint) {
	if num < 10 {
		panic("！！！！！！！！，我不行了")
	}
}

// 模拟业务错误
func func1(num uint) error {
	if num < 10 {
		return errors.Wrap(&Error{Code: ErrTypeNumber}, "[func1] failed with error:")
	}
	return nil
}

func myApp() (err error) {
	defer func() {
		var ok bool
		if ret := recover(); ret != nil {
			err, ok = ret.(error)
			if !ok {
				err = fmt.Errorf("%v", ret)
			}
			err = errors.Wrap(err, "别开玩笑，你还能行:")
			log.Printf("%s myApp panic recovered:\n%s\n%s", timeFormat(time.Now()), err, stack(3))
		}
	}()

	if err = func1(1); err != nil {
		if originalErr, ok := errors.Cause(err).(*Error); ok {
			fmt.Println("the original error coed was : ", originalErr.Code)
		} else {
			log.Printf("%v", err)
		}
	}
	func2(1)
	return
}

func main() {
	if err := myApp(); err != nil {
		log.Printf("全局处理： %v", err)
	}
}
```