---
title: GO错误处理最佳实践
date: 2019-08-17 14:24:18
categories: 
- Go
tags:
    - error
---
如何优雅地处理错误，在整个系统或框架的设计中尤其重要
<!-- more -->

## Error类型

### 业务逻辑
### 程序逻辑

## 如何处理错误

## 如何处理异常

## 自定义异常
### 错误编码
```go
const numError = 1 << 10
type customError struct {
	Code uint
}
```
### 错误信息
```go
errors.Wrap(&customError{Code: numError}, "[func1] failed with error:")
```
### Example
```go
package main

import (
	"fmt"
	"log"

	"github.com/pkg/errors"
)
const numError = 1 << 10
type customError struct {
	Code uint
}

func (c *customError) Error() string {
	return fmt.Sprintf("Failed with code %v", c.Code)
}
func func1(num uint) error {
	if num < 10 {
		return errors.Wrap(&customError{Code: numError}, "[func1] failed with error:")
	}
	return nil
}
func main() {
	if err := func1(1); err != nil {
		log.Printf("%v", err)
	}
}
```