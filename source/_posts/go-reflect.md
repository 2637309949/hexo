---
title: GO反射高效设计
date: 2019-08-20 13:54:50
categories: 
- Go
tags:
    - reflect
---
反射机制是在运行状态中，对于任意一个实体类，都能够知道这个类的所有属性和方法；对于任意一个对象，都能够调用它的任意方法和属性；这种动态获取信息以及动态调用对象方法的功能称为高级语言中的反射机制。
<!-- more -->

## 反射的作用
有时候我们需要编写一个函数能够处理一类并不满足普通公共接口的类型的值, 也可能它们併没有确定的表示方式, 或者在我们设计该函数的时候还这些类型可能还不存在, 各种情况都有可能。

## GO反射

### reflect.TypeOf
reflect.TypeOf 接受任意的 interface{} 类型, 并返回对应动态类型的reflect.Type:
```go

func app() {
    type Message struct {
        Type int
        Body []byte
    }
	messType := reflect.TypeOf(&Message{})
	log.Printf("%v", messType)
}
func main() {
	app()
}
```
如果是空值类型，则返回nil

返回的类型可能不是你想要的，考虑下面的
```go
type Message struct {
	Type int
	Body []byte
}
func app() {
	ins := reflect.MakeSlice(reflect.TypeOf([]Message{}), 0, 0).Interface()
	insType := reflect.TypeOf(&ins)
	log.Printf("%v", insType)
}
```
输出结果
```sh
2019/08/20 14:28:31 *interface {}
```

如上面的情况，笔者在设计框架时，有用户传参就是这样情况：未断言的类型，取地址后，reflect类型结果是*interface {}

解决思路：reflect后如果是interface{}类型的，我们通过Elem获取它所包含的类型值，接着再进行Type操作

```go
func app() {
	ins := reflect.MakeSlice(reflect.TypeOf([]Message{}), 0, 0).Interface()
	addIns := &ins

	insType := reflect.TypeOf(addIns)
	if reflect.TypeOf(addIns).Kind() == reflect.Ptr && reflect.TypeOf(addIns).Elem().Kind() == reflect.Interface {
		// 1.第一个Elem()获取interface{}指针指向的interface{}
		// 2.第二个Elem()获取interface{}包含的v
		// 3.第三个Elem()获取[]Message包含的Message
		insType = reflect.ValueOf(addIns).Elem().Elem().Type().Elem()
	}

	log.Printf("%v", insType)
}
```
```sh
2019/08/20 14:56:03 main.Message
```

### reflect.ValueOf
reflect.ValueOf 接受任意的 interface{} 类型, 并返回对应动态类型的reflect.Value:

```go
func app() {
	ins := reflect.MakeSlice(reflect.TypeOf([]Message{}), 0, 0).Interface()
	addIns := &ins
	insValue := reflect.ValueOf(addIns)
	log.Printf("%v", insValue.Elem().Elem().Type().Elem())
}
```
```sh
2019/08/20 15:00:10 main.Message
```

### Value，Type 与 Elem
在上面的例子中我们大量使用了Elem的方法，我们先看看Elem的定义
Elem returns the value that the interface v contains or that the pointer v points to. It panics if v's Kind is not Interface or Ptr. It returns the zero Value if v is nil.

其实在实际开发时需要十分注意的是Elem对于数组的reflect.Type返回的是单个Type，但是Elem对于数组的reflect.Value是不可用的，否则直接抛异常，所以上面我们使用

```go
log.Printf("%v", insValue.Elem().Elem().Type().Elem())
```
而不是

```go
log.Printf("%v", insValue.Elem().Elem().Elem().Type())
```


### 类型推导
```go
func app() {
	ins := reflect.MakeSlice(reflect.TypeOf([]Message{}), 0, 0).Interface()
	addIns := &ins

	insType := reflect.TypeOf(addIns)
	if reflect.TypeOf(addIns).Kind() == reflect.Ptr && reflect.TypeOf(addIns).Elem().Kind() == reflect.Interface {
		insType = reflect.ValueOf(addIns).Elem().Elem().Type()
	}
	if reflect.TypeOf(addIns).Kind() == reflect.Ptr {
		insType = insType.Elem()
	}

	i, _ := insType.FieldByName("Type")
	log.Printf("%v", i.Type)
}
```
1. 先判断是否*interface{}，如果是则先取值后Type
2. 接着判断是否*xx类型，如果是则取指针所指向的类型
3. 判断是否数组类型，如果是则取数组所包含的类型
4. 具体的reflect运算

## 反射应用
实际中有很多反射的应用操作，这里只简单介绍两个范围的常用应用

### 创建实例
```go
func createObject(target interface{}) interface{} {
    insType := reflect.TypeOf(target)
	if reflect.TypeOf(addIns).Kind() == reflect.Ptr && reflect.TypeOf(addIns).Elem().Kind() == reflect.Interface {
		insType = reflect.ValueOf(addIns).Elem().Elem().Type()
	}
	if reflect.TypeOf(addIns).Kind() == reflect.Ptr {
		insType = insType.Elem()
    }
	return reflect.New(insType).Interface()
}
```
### 注入实体
```go
func (scope *Scope) callMethod(methodName string, reflectValue reflect.Value) {
	if reflectValue.CanAddr() && reflectValue.Kind() != reflect.Ptr {
		reflectValue = reflectValue.Addr()
	}
	if methodValue := reflectValue.MethodByName(methodName); methodValue.IsValid() {
		switch method := methodValue.Interface().(type) {
		case func():
			method()
		case func(*Scope):
			method(scope)
		case func(*DB):
			newDB := scope.NewDB()
			method(newDB)
			scope.Err(newDB.Error)
		case func() error:
			scope.Err(method())
		case func(*Scope) error:
			scope.Err(method(scope))
		case func(*DB) error:
			newDB := scope.NewDB()
			scope.Err(method(newDB))
			scope.Err(newDB.Error)
		default:
			scope.Err(fmt.Errorf("unsupported function %v", methodName))
		}
	}
}
```

## GO反射缺点
