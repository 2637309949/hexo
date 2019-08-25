---
title: GO函数拓展
date: 2019-08-24 17:46:54
categories: 
- Go
tags:
	- fp
---

GO语言比较适合命令式编程（如果稍微适应函数式会好很多，不过我们这里使用reflect方式来稍微拓展func这一边，使其函数运用起来更加高级），这一块我们专注拓展，如：Monad, Functional Programming以及其他高级函数特性，且重点学习如何实现常见的Map，ForEach等，实际应用中我们直接使用开源的lib即可。

<!-- more -->

## GO函数

### Variadic函数
使用Variadic函数可以创造很多高级用法，如下我们我可以传入不同类型参数，用interface{}来接受。
```go
package main

import (
	"fmt"
	"reflect"
)

func testFunc(params ...interface{}) {
	fmt.Println(params[len(params)-1].(*struct{ Name string }))
	fmt.Println(params[len(params)-2].(string))
}
func main() {
	testFunc(1, 2, "34", &struct{ Name string }{})
}

```

结合reflect获取反射信息，让函数更加灵活。
```go
package main

import (
	"fmt"
	"reflect"
)

func testFunc(params ...interface{}) {
	reflect.ValueOf(params[len(params)-1].(*struct{ Name string })).Elem().FieldByName("Name").SetString("ok")
	fmt.Println(params[len(params)-1].(*struct{ Name string }))
	fmt.Println(params[len(params)-2].(string))
}
func main() {
	testFunc(1, 2, "34", &struct{ Name string }{})
}

```

或者传入函数, Variadic函数在很多框架的中间件会用到，也是结合reflect创建出更多弹性的配置。
```go
package main

import (
	"fmt"
	"reflect"
)

func testFunc(params ...interface{}) {
	reflect.ValueOf(params[len(params)-1].(*struct{ Name string })).Elem().FieldByName("Name").SetString("ok")
	fmt.Println(params[len(params)-1].(*struct{ Name string }))
	fmt.Println(params[len(params)-2].(string))
	reflect.ValueOf(params[len(params)-3]).Call([]reflect.Value{})
}
func main() {
	testFunc(1, 2, func() {
		fmt.Println("hello")
	}, "34", &struct{ Name string }{})
}
```
```sh
[Running] go run "/home/double/Work/GO/demo/tempCodeRunnerFile.go"
&{ok}
34
hello

[Done] exited with code=0 in 0.189 seconds
```

### reflect匹配函数签名

在静态语言中，任何变量或函数或其他类型只有类型断言确定后才能操作，我们下面举例通过函数断言的方式来调用多种函数参数。

```go
package main

import (
	"fmt"
)

func testSubFunc(name string) (err error) {
	fmt.Println(name)
	return
}

func testSubFunc2(age int) (err error) {
	fmt.Println(age)
	return
}

func testFunc(params ...interface{}) {
	for _, v := range params {
		switch method := v.(type) {
		case func(string) error:
			method("hello")
		case func(int) error:
			method(12)
		}
	}
}
func main() {
	testFunc(testSubFunc, testSubFunc2)
}
```

### reflect动态注入参数
#### 断言函数签名
```go
package main

import (
	"fmt"
)

func testSubFunc(name string) (err error) {
	fmt.Println(name)
	return
}

func testSubFunc2(age int) (err error) {
	fmt.Println(age)
	return
}

func testFunc(params ...interface{}) {
	for _, v := range params {
		switch method := v.(type) {
		case func(string) error:
			method("hello")
		case func(int) error:
			method(12)
		}
	}
}
func main() {
	testFunc(testSubFunc, testSubFunc2)
}
```

#### reflect函数参数

我们也可以通过反射获取具体的参数类型然后在填充该类型的变量。
```go
funk.Type().In(i)
```

```go
func (scope *Scope) inFrom(inputs []interface{}) {
	funk := scope.indirectPlugin()
	if funk.Type().Kind() != reflect.Func {
		panic(fmt.Errorf(" %v inputsFrom call with %v error", funk, inputs))
	}
	funcType := funk.Type()
	numIn := funcType.NumIn()
	for index := 0; index < numIn; index++ {
		ptype := funcType.In(index)
		eleValue := typeMatcher(ptype, inputs)
		if eleValue == nil {
			if eleValue = duckMatcher(ptype, inputs); eleValue == nil {
				panic(fmt.Errorf("inputsFrom %v call with %v error", ptype, reflect.TypeOf(inputs)))
			}
		}
		scope.Inputs = append(scope.Inputs, eleValue.(reflect.Value))
	}
}
```

### reflect动态调用

最后我们可以通过value的Call方式调用对应的函数，该函数的返回值是value的数组。
```go
func (scope *Scope) reflectCall(m reflect.Value, ins []reflect.Value) []interface{} {
	return funk.Map(m.Call(ins), func(v reflect.Value) interface{} {
		return v.Interface()
	}).([]interface{})
}
```
## Array

### Map

实现Map函数
```go
package main

import (
	"fmt"
	"reflect"
)

func IsIteratee(in interface{}) bool {
	arrType := reflect.TypeOf(in)
	kind := arrType.Kind()
	return kind == reflect.Array || kind == reflect.Slice || kind == reflect.Map
}

func IsFunction(in interface{}, num ...int) bool {
	funcType := reflect.TypeOf(in)
	result := funcType.Kind() == reflect.Func
	if len(num) >= 1 {
		result = result && funcType.NumIn() == num[0]
	}
	if len(num) == 2 {
		result = result && funcType.NumOut() == num[1]
	}
	return result
}

func mapSlice(arrValue reflect.Value, funcValue reflect.Value) interface{} {
	funcType := funcValue.Type()
	if funcType.NumIn() != 1 || funcType.NumOut() == 0 || funcType.NumOut() > 2 {
		panic("Map function with an array must have one parameter and must return one or two parameters")
	}
	arrElemType := arrValue.Type().Elem()
	if !arrElemType.ConvertibleTo(funcType.In(0)) {
		panic("Map function's argument is not compatible with type of array.")
	}

	if funcType.NumOut() == 1 {
		resultSliceType := reflect.SliceOf(funcType.Out(0))
		resultSlice := reflect.MakeSlice(resultSliceType, 0, 0)
		for i := 0; i < arrValue.Len(); i++ {
			result := funcValue.Call([]reflect.Value{arrValue.Index(i)})[0]

			resultSlice = reflect.Append(resultSlice, result)
		}
		return resultSlice.Interface()
	}
	if funcType.NumOut() == 2 {
		collectionType := reflect.MapOf(funcType.Out(0), funcType.Out(1))
		collection := reflect.MakeMap(collectionType)
		for i := 0; i < arrValue.Len(); i++ {
			results := funcValue.Call([]reflect.Value{arrValue.Index(i)})

			collection.SetMapIndex(results[0], results[1])
		}
		return collection.Interface()
	}
	return nil
}

func mapMap(arrValue reflect.Value, funcValue reflect.Value) interface{} {
	funcType := funcValue.Type()
	if funcType.NumIn() != 2 || funcType.NumOut() == 0 || funcType.NumOut() > 2 {
		panic("Map function with an map must have one parameter and must return one or two parameters")
	}
	if funcType.NumOut() == 1 {
		resultSliceType := reflect.SliceOf(funcType.Out(0))
		resultSlice := reflect.MakeSlice(resultSliceType, 0, 0)
		for _, key := range arrValue.MapKeys() {
			results := funcValue.Call([]reflect.Value{key, arrValue.MapIndex(key)})
			result := results[0]
			resultSlice = reflect.Append(resultSlice, result)
		}
		return resultSlice.Interface()
	}
	if funcType.NumOut() == 2 {
		collectionType := reflect.MapOf(funcType.Out(0), funcType.Out(1))
		collection := reflect.MakeMap(collectionType)
		for _, key := range arrValue.MapKeys() {
			results := funcValue.Call([]reflect.Value{key, arrValue.MapIndex(key)})
			collection.SetMapIndex(results[0], results[1])
		}
		return collection.Interface()
	}
	return nil
}

func Map(arr interface{}, mapFunc interface{}) interface{} {
	if !IsIteratee(arr) {
		panic("First parameter must be an iteratee")
	}
	if !IsFunction(mapFunc) {
		panic("Second argument must be function")
	}
	var (
		funcValue = reflect.ValueOf(mapFunc)
		arrValue  = reflect.ValueOf(arr)
		arrType   = arrValue.Type()
	)
	kind := arrType.Kind()
	if kind == reflect.Slice || kind == reflect.Array {
		return mapSlice(arrValue, funcValue)
	}
	if kind == reflect.Map {
		return mapMap(arrValue, funcValue)
	}
	panic(fmt.Sprintf("Type %s is not supported by Map", arrType.String()))
}

```

使用Map函数
```go
func main() {
	ret := Map([]int{1, 2, 3}, func(i int) int {
		return i * i
	})
	fmt.Println(ret)
}
```

### ForEach

实现ForEach函数
```go
package main

import (
	"fmt"
	"reflect"
)

func IsIteratee(in interface{}) bool {
	arrType := reflect.TypeOf(in)

	kind := arrType.Kind()

	return kind == reflect.Array || kind == reflect.Slice || kind == reflect.Map
}

func IsFunction(in interface{}, num ...int) bool {
	funcType := reflect.TypeOf(in)

	result := funcType.Kind() == reflect.Func

	if len(num) >= 1 {
		result = result && funcType.NumIn() == num[0]
	}

	if len(num) == 2 {
		result = result && funcType.NumOut() == num[1]
	}

	return result
}

func ForEach(arr interface{}, predicate interface{}) {
	if !IsIteratee(arr) {
		panic("First parameter must be an iteratee")
	}
	var (
		funcValue = reflect.ValueOf(predicate)
		arrValue  = reflect.ValueOf(arr)
		arrType   = arrValue.Type()
		funcType  = funcValue.Type()
	)
	if arrType.Kind() == reflect.Slice || arrType.Kind() == reflect.Array {
		if !IsFunction(predicate, 1, 0) {
			panic("Second argument must be a function with one parameter")
		}
		arrElemType := arrValue.Type().Elem()
		if !arrElemType.ConvertibleTo(funcType.In(0)) {
			panic("Map function's argument is not compatible with type of array.")
		}

		for i := 0; i < arrValue.Len(); i++ {
			funcValue.Call([]reflect.Value{arrValue.Index(i)})
		}
	}

	if arrType.Kind() == reflect.Map {
		if !IsFunction(predicate, 2, 0) {
			panic("Second argument must be a function with two parameters")
		}

		keyType := arrType.Key()
		valueType := arrType.Elem()

		if !keyType.ConvertibleTo(funcType.In(0)) {
			panic(fmt.Sprintf("function first argument is not compatible with %s", keyType.String()))
		}

		if !valueType.ConvertibleTo(funcType.In(1)) {
			panic(fmt.Sprintf("function second argument is not compatible with %s", valueType.String()))
		}

		for _, key := range arrValue.MapKeys() {
			funcValue.Call([]reflect.Value{key, arrValue.MapIndex(key)})
		}
	}
}
```

使用ForEach函数
```go
func main() {
	ForEach([]int{1, 2, 3}, func(i int) {
		fmt.Println(i)
	})
}
```

## Monad
In functional programming, a monad is a design pattern[1] that allows structuring programs generically while automating away boilerplate code needed by the program logic. Monads achieve this by providing their own data type, which represents a specific form of computation, along with one procedure to wrap values of any basic type within the monad (yielding a monadic value) and another to compose functions that output monadic values (called monadic functions).[2]

This allows monads to simplify a wide range of problems, like handling potential undefined values (with the Maybe monad), or keeping values within a flexible, well-formed list (using the List monad). With a monad, a programmer can turn a complicated sequence of functions into a succinct pipeline that abstracts away auxiliary data management, control flow, or side-effects.[2][3]

Both the concept of a monad and the term originally come from category theory, where it is defined as a functor with additional structure.[a] Research beginning in the late 1980s and early 1990s established that monads could bring seemingly disparate computer-science problems under a unified, functional model. Category theory also provides a few formal requirements, known as the monad laws, which should be satisfied by any monad and can be used to verify monadic code.[4][5]

Since monads make semantics explicit for a kind of computation, they can also be used to implement convenient language features. Some languages, such as Haskell, even offer pre-built definitions in their core libraries for the general monad structure and common instances.[2][6]

Definition
The more common definition for a monad in functional programming, used in the above example, is actually based on a Kleisli triple rather than category theory's standard definition. The two constructs turn out to be mathematically equivalent, however, so either definition will yield a valid monad. Given any well-defined, basic types T, U, a monad consists of three parts:

- A type constructor M that builds up a monadic type M T[b]
- A type converter, often called unit or return, that embeds an object x in the monad:
unit(x) : T → M T[c]
- A combinator, typically called bind (as in binding a variable) and represented with an infix operator >>=, that unwraps a monadic variable, then inserts it into a monadic function/expression, resulting in a new monadic value:
(mx >>= f) : (M T, T → M U) → M U[d]

To fully qualify as a monad though, these three parts must also respect a few laws:

- unit is a left-identity for bind:
- unit(a) >>= λx → f(x) ↔ f(a)
- unit is also a right-identity for bind:
ma >>= λx → unit(x) ↔ ma
- bind is essentially associative:[e]
ma >>= λx → (f(x) >>= λy → g(y)) ↔ (ma >>= λx → f(x)) >>= λy → g(y)[2]
Algebraically, this means any monad both gives rise to a category (called the Kleisli category) and a monoid in the category of functors (from values to computations), with monadic composition as a binary operator and unit as identity.[citation needed]

`有空再整理出一片函数式领域编程的知识点`

### Optional

实现Optional
[https://github.com/TeaEntityLab/fpGo/blob/master/maybe.go](https://github.com/TeaEntityLab/fpGo/blob/master/maybe.go)

```go
package fpGo

import (
	"errors"
	"fmt"
	"reflect"
	"strconv"
)

// MaybeDef Maybe inspired by Rx/Optional/Guava/Haskell
type MaybeDef struct {
	ref interface{}
}

// Just New Maybe by a given value
func (maybeSelf MaybeDef) Just(in interface{}) MaybeDef {
	return MaybeDef{ref: in}
}

// Or Check the value wrapped by Maybe, if it's nil then return a given fallback value
func (maybeSelf MaybeDef) Or(or interface{}) interface{} {
	if maybeSelf.IsNil() {
		return or
	}

	return maybeSelf.ref
}

// CloneTo Clone the Ptr target to an another Ptr target
func (maybeSelf MaybeDef) CloneTo(dest interface{}) MaybeDef {
	if maybeSelf.IsNil() {
		return maybeSelf.Just(nil)
	}

	x := reflect.ValueOf(maybeSelf.ref)
	if x.Kind() == reflect.Ptr {
		starX := x.Elem()
		y := reflect.New(starX.Type())
		starY := y.Elem()
		starY.Set(starX)
		reflect.ValueOf(dest).Elem().Set(y.Elem())
		return maybeSelf.Just(dest)
	}
	dest = x.Interface()

	return maybeSelf.Just(dest)
}

// Clone Clone Maybe object & its wrapped value
func (maybeSelf MaybeDef) Clone() MaybeDef {
	return maybeSelf.CloneTo(new(interface{}))
}

// FlatMap FlatMap Maybe by function
func (maybeSelf MaybeDef) FlatMap(fn func(interface{}) *MaybeDef) *MaybeDef {
	return fn(maybeSelf.ref)
}

// ToString Maybe to String
func (maybeSelf MaybeDef) ToString() string {
	if maybeSelf.IsNil() {
		return "<nil>"
	}

	ref := maybeSelf.ref
	switch (ref).(type) {
	default:
		return fmt.Sprintf("%v", ref)
	case int:
		return strconv.Itoa((ref).(int))
	case string:
		return (ref).(string)
	}
}

// ToPtr Maybe to Ptr
func (maybeSelf MaybeDef) ToPtr() *interface{} {
	if maybeSelf.Kind() == reflect.Ptr {
		val := reflect.Indirect(reflect.ValueOf(maybeSelf.ref)).Interface()
		return &val
	}

	return &maybeSelf.ref
}

// ToMaybe Maybe to Maybe
func (maybeSelf MaybeDef) ToMaybe() MaybeDef {
	if maybeSelf.IsNil() {
		return maybeSelf
	}

	var ref = maybeSelf.ref
	switch (ref).(type) {
	default:
		return maybeSelf
	case MaybeDef:
		return (ref).(MaybeDef)
	}
}

// ToFloat64 Maybe to Float64
func (maybeSelf MaybeDef) ToFloat64() (float64, error) {
	if maybeSelf.IsNil() {
		return float64(0), errors.New("<nil>")
	}

	ref := maybeSelf.ref
	switch (ref).(type) {
	default:
		return float64(0), errors.New("unsupported")
	case string:
		return strconv.ParseFloat(maybeSelf.ToString(), 64)
	case bool:
		val, err := maybeSelf.ToBool()
		if val {
			return float64(1), err
		}
		return float64(0), err
	case int:
		val, err := maybeSelf.ToInt()
		return float64(val), err
	case int32:
		val, err := maybeSelf.ToInt32()
		return float64(val), err
	case int64:
		val, err := maybeSelf.ToInt64()
		return float64(val), err
	case float32:
		val, err := maybeSelf.ToFloat32()
		return float64(val), err
	case float64:
		return (ref).(float64), nil
	}
}

// ToFloat32 Maybe to Float32
func (maybeSelf MaybeDef) ToFloat32() (float32, error) {
	if maybeSelf.IsNil() {
		return float32(0), errors.New("<nil>")
	}

	ref := maybeSelf.ref
	switch (ref).(type) {
	default:
		return float32(0), errors.New("unsupported")
	case string:
		val, err := strconv.ParseFloat(maybeSelf.ToString(), 32)
		return float32(val), err
	case bool:
		val, err := maybeSelf.ToBool()
		if val {
			return float32(1), err
		}
		return float32(0), err
	case int:
		val, err := maybeSelf.ToInt()
		return float32(val), err
	case int32:
		val, err := maybeSelf.ToInt32()
		return float32(val), err
	case int64:
		val, err := maybeSelf.ToInt64()
		return float32(val), err
	case float32:
		return (ref).(float32), nil
	case float64:
		val, err := maybeSelf.ToFloat64()
		return float32(val), err
	}
}

// ToInt Maybe to Int
func (maybeSelf MaybeDef) ToInt() (int, error) {
	if maybeSelf.IsNil() {
		return int(0), errors.New("<nil>")
	}

	ref := maybeSelf.ref
	switch (ref).(type) {
	default:
		return int(0), errors.New("unsupported")
	case string:
		return strconv.Atoi(maybeSelf.ToString())
	case bool:
		val, err := maybeSelf.ToBool()
		if val {
			return int(1), err
		}
		return int(0), err
	case int:
		return (ref).(int), nil
	case int32:
		val, err := maybeSelf.ToInt32()
		return int(val), err
	case int64:
		val, err := maybeSelf.ToInt64()
		return int(val), err
	case float32:
		val, err := maybeSelf.ToFloat32()
		return int(val), err
	case float64:
		val, err := maybeSelf.ToFloat64()
		return int(val), err
	}
}

// ToInt32 Maybe to Int32
func (maybeSelf MaybeDef) ToInt32() (int32, error) {
	if maybeSelf.IsNil() {
		return int32(0), errors.New("<nil>")
	}

	ref := maybeSelf.ref
	switch (ref).(type) {
	default:
		return int32(0), errors.New("unsupported")
	case string:
		val, err := maybeSelf.ToInt64()
		return int32(val), err
	case bool:
		val, err := maybeSelf.ToBool()
		if val {
			return int32(1), err
		}
		return int32(0), err
	case int:
		val, err := maybeSelf.ToInt()
		return int32(val), err
	case int32:
		return (ref).(int32), nil
	case int64:
		val, err := maybeSelf.ToInt64()
		return int32(val), err
	case float32:
		val, err := maybeSelf.ToFloat32()
		return int32(val), err
	case float64:
		val, err := maybeSelf.ToFloat64()
		return int32(val), err
	}
}

// ToInt64 Maybe to Int64
func (maybeSelf MaybeDef) ToInt64() (int64, error) {
	if maybeSelf.IsNil() {
		return int64(0), errors.New("<nil>")
	}

	ref := maybeSelf.ref
	switch (ref).(type) {
	default:
		return int64(0), errors.New("unsupported")
	case string:
		return strconv.ParseInt(maybeSelf.ToString(), 10, 32)
	case bool:
		val, err := maybeSelf.ToBool()
		if val {
			return int64(1), err
		}
		return int64(0), err
	case int:
		val, err := maybeSelf.ToInt()
		return int64(val), err
	case int32:
		val, err := maybeSelf.ToInt32()
		return int64(val), err
	case int64:
		return (ref).(int64), nil
	case float32:
		val, err := maybeSelf.ToFloat32()
		return int64(val), err
	case float64:
		val, err := maybeSelf.ToFloat64()
		return int64(val), err
	}
}

// ToBool Maybe to Bool
func (maybeSelf MaybeDef) ToBool() (bool, error) {
	if maybeSelf.IsNil() {
		return bool(false), errors.New("<nil>")
	}

	ref := maybeSelf.ref
	switch (ref).(type) {
	default:
		return bool(false), errors.New("unsupported")
	case string:
		return strconv.ParseBool(maybeSelf.ToString())
	case bool:
		return (ref).(bool), nil
	case int:
		val, err := maybeSelf.ToInt()
		return bool(val != 0), err
	case int32:
		val, err := maybeSelf.ToInt32()
		return bool(val != 0), err
	case int64:
		val, err := maybeSelf.ToInt64()
		return bool(val != 0), err
	case float32:
		val, err := maybeSelf.ToFloat32()
		return bool(val != 0), err
	case float64:
		val, err := maybeSelf.ToFloat64()
		return bool(val != 0), err
	}
}

// Let If the wrapped value is not nil, then do the given function
func (maybeSelf MaybeDef) Let(fn func()) {
	if maybeSelf.IsPresent() {
		fn()
	}
}

// Unwrap Unwrap the wrapped value of Maybe
func (maybeSelf MaybeDef) Unwrap() interface{} {
	if maybeSelf.IsNil() {
		return nil
	}

	return maybeSelf.ref
}

// IsPresent Check is it present(not nil)
func (maybeSelf MaybeDef) IsPresent() bool {
	return !(maybeSelf.IsNil())
}

// IsNil Check is it nil
func (maybeSelf MaybeDef) IsNil() bool {
	val := reflect.ValueOf(maybeSelf.ref)

	if maybeSelf.Kind() == reflect.Ptr {
		return val.IsNil()
	}
	return !val.IsValid()
}

// IsValid Check is its reflect.ValueOf(ref) valid
func (maybeSelf MaybeDef) IsValid() bool {
	val := reflect.ValueOf(maybeSelf.ref)
	return val.IsValid()
}

// Type Get its Type
func (maybeSelf MaybeDef) Type() reflect.Type {
	if maybeSelf.IsNil() {
		return reflect.TypeOf(nil)
	}
	return reflect.TypeOf(maybeSelf.ref)
}

// Kind Get its Kind
func (maybeSelf MaybeDef) Kind() reflect.Kind {
	return reflect.ValueOf(maybeSelf.ref).Kind()
}

// IsType Check is its Type equal to the given one
func (maybeSelf MaybeDef) IsType(t reflect.Type) bool {
	return maybeSelf.Type() == t
}

// IsKind Check is its Kind equal to the given one
func (maybeSelf MaybeDef) IsKind(t reflect.Kind) bool {
	return maybeSelf.Kind() == t
}

// Maybe Maybe utils instance
var Maybe MaybeDef
```

使用
```go
var m MaybeDef
var orVal int
var boolVal bool

// IsPresent(), IsNil()
m = Maybe.Just(1)
boolVal = m.IsPresent() // true
boolVal = m.IsNil() // false
m = Maybe.Just(nil)
boolVal = m.IsPresent() // false
boolVal = m.IsNil() // true

// Or()
m = Maybe.Just(1)
fmt.Println((m.Or(3))) // 1
m = Maybe.Just(nil)
fmt.Println((m.Or(3))) // 3

// Let()
var letVal int
letVal = 1
m = Maybe.Just(1)
m.Let(func() {
  letVal = 2
})
fmt.Println(letVal) // letVal would be 2

letVal = 1
m = Maybe.Just(nil)
m.Let(func() {
  letVal = 3
})
fmt.Println(letVal) // letVal would be still 1
```

### MonadIO

实现MonadIO
[https://github.com/TeaEntityLab/fpGo/blob/master/monadIO.go](https://github.com/TeaEntityLab/fpGo/blob/master/monadIO.go)

```go
package fpGo

// MonadIODef MonadIO inspired by Rx/Observable
type MonadIODef struct {
	effect func() interface{}

	obOn  *HandlerDef
	subOn *HandlerDef
}

// Subscription the delegation/callback of MonadIO/Publisher
type Subscription struct {
	OnNext func(interface{})
}

// Just New MonadIO by a given value
func (monadIOSelf MonadIODef) Just(in interface{}) *MonadIODef {
	return &MonadIODef{effect: func() interface{} {
		return in
	}}
}

// New New MonadIO by effect function
func (monadIOSelf *MonadIODef) New(effect func() interface{}) *MonadIODef {
	return &MonadIODef{effect: effect}
}

// FlatMap FlatMap the MonadIO by function
func (monadIOSelf *MonadIODef) FlatMap(fn func(interface{}) *MonadIODef) *MonadIODef {

	return &MonadIODef{effect: func() interface{} {
		next := fn(monadIOSelf.doEffect())
		return next.doEffect()
	}}

}

// Subscribe Subscribe the MonadIO by Subscription
func (monadIOSelf *MonadIODef) Subscribe(s Subscription) *Subscription {
	obOn := monadIOSelf.obOn
	subOn := monadIOSelf.subOn
	return monadIOSelf.doSubscribe(&s, obOn, subOn)
}

// SubscribeOn Subscribe the MonadIO on the specific Handler
func (monadIOSelf *MonadIODef) SubscribeOn(h *HandlerDef) *MonadIODef {
	monadIOSelf.subOn = h
	return monadIOSelf
}

// ObserveOn Observe the MonadIO on the specific Handler
func (monadIOSelf *MonadIODef) ObserveOn(h *HandlerDef) *MonadIODef {
	monadIOSelf.obOn = h
	return monadIOSelf
}
func (monadIOSelf *MonadIODef) doSubscribe(s *Subscription, obOn *HandlerDef, subOn *HandlerDef) *Subscription {

	if s.OnNext != nil {
		var result interface{}

		doSub := func() {
			s.OnNext(result)
		}
		doOb := func() {
			result = monadIOSelf.doEffect()

			if subOn != nil {
				subOn.Post(doSub)
			} else {
				doSub()
			}
		}
		if obOn != nil {
			obOn.Post(doOb)
		} else {
			doOb()
		}
	}

	return s
}
func (monadIOSelf *MonadIODef) doEffect() interface{} {
	return monadIOSelf.effect()
}

// MonadIO MonadIO utils instance
var MonadIO MonadIODef
```

使用
```go
var m *MonadIODef
var actualInt int

m = MonadIO.Just(1)
actualInt = 0
m.Subscribe(Subscription{
  OnNext: func(in interface{}) {
    actualInt, _ = Maybe.Just(in).ToInt()
  },
})
fmt.Println(actualInt) // actualInt would be 1

m = MonadIO.Just(1).FlatMap(func(in interface{}) *MonadIODef {
  v, _ := Maybe.Just(in).ToInt()
  return MonadIO.Just(v + 1)
})
actualInt = 0
m.Subscribe(Subscription{
  OnNext: func(in interface{}) {
    actualInt, _ = Maybe.Just(in).ToInt()
  },
})
fmt.Println(actualInt) // actualInt would be 2
```

### Stream

实现Stream
[https://github.com/TeaEntityLab/fpGo/blob/master/stream.go](https://github.com/TeaEntityLab/fpGo/blob/master/stream.go)

```go
package fpGo

import (
	"sort"
)

// StreamDef Stream inspired by Collection utils
type StreamDef struct {
	list []interface{}
}

// FromArrayMaybe FromArrayMaybe New Stream instance from a Maybe array
func (streamSelf *StreamDef) FromArrayMaybe(old []MaybeDef) *StreamDef {
	new := make([]interface{}, len(old))
	for i, v := range old {
		var item interface{} = v
		new[i] = item
	}

	return streamSelf.FromArray(new)
}

// FromArrayString New Stream instance from a string array
func (streamSelf *StreamDef) FromArrayString(old []string) *StreamDef {
	new := make([]interface{}, len(old))
	for i, v := range old {
		var item interface{} = v
		new[i] = item
	}

	return streamSelf.FromArray(new)
}

// FromArrayBool New Stream instance from a bool array
func (streamSelf *StreamDef) FromArrayBool(old []bool) *StreamDef {
	new := make([]interface{}, len(old))
	for i, v := range old {
		var item interface{} = v
		new[i] = item
	}

	return streamSelf.FromArray(new)
}

// FromArrayInt New Stream instance from an int array
func (streamSelf *StreamDef) FromArrayInt(old []int) *StreamDef {
	new := make([]interface{}, len(old))
	for i, v := range old {
		var item interface{} = v
		new[i] = item
	}

	return streamSelf.FromArray(new)
}

// FromArrayInt32 New Stream instance from an int32 array
func (streamSelf *StreamDef) FromArrayInt32(old []int32) *StreamDef {
	new := make([]interface{}, len(old))
	for i, v := range old {
		var item interface{} = v
		new[i] = item
	}

	return streamSelf.FromArray(new)
}

// FromArrayInt64 New Stream instance from an int64 array
func (streamSelf *StreamDef) FromArrayInt64(old []int64) *StreamDef {
	new := make([]interface{}, len(old))
	for i, v := range old {
		var item interface{} = v
		new[i] = item
	}

	return streamSelf.FromArray(new)
}

// FromArrayFloat32 New Stream instance from a float32 array
func (streamSelf *StreamDef) FromArrayFloat32(old []float32) *StreamDef {
	new := make([]interface{}, len(old))
	for i, v := range old {
		var item interface{} = v
		new[i] = item
	}

	return streamSelf.FromArray(new)
}

// FromArrayFloat64 New Stream instance from a float64 array
func (streamSelf *StreamDef) FromArrayFloat64(old []float64) *StreamDef {
	new := make([]interface{}, len(old))
	for i, v := range old {
		var item interface{} = v
		new[i] = item
	}

	return streamSelf.FromArray(new)
}

// FromArray New Stream instance from an interface{} array
func (streamSelf *StreamDef) FromArray(list []interface{}) *StreamDef {
	return &StreamDef{list: list}
}

// ToArray Convert Stream to slice
func (streamSelf *StreamDef) ToArray() []interface{} {
	return streamSelf.list
}

// Map Map all items of Stream by function
func (streamSelf *StreamDef) Map(fn func(int) interface{}) *StreamDef {

	var list = make([]interface{}, streamSelf.Len())

	for i := range streamSelf.list {
		list[i] = fn(i)
	}

	return &StreamDef{list: list}
}

// Filter Filter items of Stream by function
func (streamSelf *StreamDef) Filter(fn func(int) bool) *StreamDef {

	var list = make([]interface{}, streamSelf.Len())

	var newLen = 0

	for i := range streamSelf.list {
		if fn(i) {
			newLen++
			list[newLen-1] = streamSelf.list[i]
		}
	}

	return &StreamDef{list: list[:newLen]}
}

// Distinct Filter not nil items and return a new Stream instance
func (streamSelf *StreamDef) Distinct() *StreamDef {
	return streamSelf.Filter(func(i int) bool {
		return Maybe.Just(streamSelf.list[i]).IsPresent()
	})
}

// Append Append an item into Stream
func (streamSelf *StreamDef) Append(item interface{}) *StreamDef {
	streamSelf.list = append(streamSelf.list, item)
	return streamSelf
}

// Remove Remove an item by its index
func (streamSelf *StreamDef) Remove(index int) *StreamDef {
	if index >= 0 && index < streamSelf.Len() {
		streamSelf.list = append(streamSelf.list[:index], streamSelf.list[index+1:]...)
	}
	return streamSelf
}

// Len Get length of Stream
func (streamSelf *StreamDef) Len() int {
	return len(streamSelf.list)
}

// Extend Extend Stream by an another Stream
func (streamSelf *StreamDef) Extend(stream *StreamDef) *StreamDef {
	if stream == nil {
		return streamSelf
	}

	var mine = streamSelf.list
	var mineLen = len(mine)
	var target = stream.ToArray()
	var targetLen = len(target)

	var new = make([]interface{}, mineLen+targetLen)
	for i, item := range mine {
		new[i] = item
	}
	for j, item := range target {
		new[mineLen+j] = item
	}
	streamSelf.list = new

	return streamSelf
}

// Sort Sort Stream items by function
func (streamSelf *StreamDef) Sort(fn func(i, j int) bool) *StreamDef {
	sort.Slice(streamSelf.list, fn)
	return streamSelf
}

// Get Get an item of Stream by its index
func (streamSelf *StreamDef) Get(i int) interface{} {
	return streamSelf.list[i]
}

// Stream Stream utils instance
var Stream StreamDef
```

使用
```go
var s *StreamDef
var tempString = ""

s = Stream.FromArrayInt([]int{}).Append(1).Extend(Stream.FromArrayInt([]int{2, 3, 4})).Extend(Stream.FromArray([]interface{}{nil}))
tempString = ""
for _, v := range s.ToArray() {
  tempString += Maybe.Just(v).ToMaybe().ToString()
}
fmt.Println(tempString) // tempString would be "1234<nil>"
s = s.Distinct()
tempString = ""
for _, v := range s.ToArray() {
  tempString += Maybe.Just(v).ToMaybe().ToString()
}
fmt.Println(tempString) // tempString would be "1234"
```

### Compose

实现Compose
[https://github.com/TeaEntityLab/fpGo/blob/master/fp.go](https://github.com/TeaEntityLab/fpGo/blob/master/fp.go)

```go
package fpGo

import (
	"fmt"
	"reflect"
	"regexp"
	"sync"
)

type fnObj func(interface{}) interface{}

// Compose Compose the functions from right to left (Math: f(g(x)) Compose: Compose(f, g)(x))
func Compose(fnList ...func(...interface{}) []interface{}) func(...interface{}) []interface{} {
	return func(s ...interface{}) []interface{} {
		f := fnList[0]
		nextFnList := fnList[1:]

		if len(fnList) == 1 {
			return f(s...)
		}

		return f(Compose(nextFnList...)(s...)...)
	}
}

// PtrOf Return Ptr of a value
func PtrOf(v interface{}) *interface{} {
	return &v
}

// SliceOf Return Slice of varargs
func SliceOf(args ...interface{}) []interface{} {
	return args
}

// CurryDef Curry inspired by Currying in Java ways
type CurryDef struct {
	fn     func(c *CurryDef, args ...interface{}) interface{}
	result interface{}
	isDone AtomBool

	callM sync.Mutex
	args  []interface{}
}

// New New Curry instance by function
func (currySelf *CurryDef) New(fn func(c *CurryDef, args ...interface{}) interface{}) *CurryDef {
	c := &CurryDef{fn: fn}

	return c
}

// Call Call the currying function by partial or all args
func (currySelf *CurryDef) Call(args ...interface{}) *CurryDef {
	currySelf.callM.Lock()
	if !currySelf.isDone.Get() {
		currySelf.args = append(currySelf.args, args...)
		currySelf.result = currySelf.fn(currySelf, currySelf.args...)
	}
	currySelf.callM.Unlock()
	return currySelf
}

// MarkDone Mark the currying is done(let others know it)
func (currySelf *CurryDef) MarkDone() {
	currySelf.isDone.Set(true)
}

// IsDone Is the currying done
func (currySelf *CurryDef) IsDone() bool {
	return currySelf.isDone.Get()
}

// Result Get the result value of currying
func (currySelf *CurryDef) Result() interface{} {
	return currySelf.result
}

// Curry Curry utils instance
var Curry CurryDef

// PatternMatching

// Pattern Pattern general interface
type Pattern interface {
	Matches(value interface{}) bool
	Apply(interface{}) interface{}
}

// PatternMatching PatternMatching contains Pattern list
type PatternMatching struct {
	patterns []Pattern
}

// KindPatternDef Pattern which matching when the kind matches
type KindPatternDef struct {
	kind   reflect.Kind
	effect fnObj
}

// CompTypePatternDef Pattern which matching when the SumType matches
type CompTypePatternDef struct {
	compType CompType
	effect   fnObj
}

// EqualPatternDef Pattern which matching when the given object is equal to predefined one
type EqualPatternDef struct {
	value  interface{}
	effect fnObj
}

// RegexPatternDef Pattern which matching when the regex rule matches the given string
type RegexPatternDef struct {
	pattern string
	effect  fnObj
}

// OtherwisePatternDef Pattern which matching when the others didn't match(finally)
type OtherwisePatternDef struct {
	effect fnObj
}

// MatchFor Check does the given value match anyone of the Pattern list of PatternMatching
func (patternMatchingSelf PatternMatching) MatchFor(inValue interface{}) interface{} {
	for _, pattern := range patternMatchingSelf.patterns {
		value := inValue
		maybe := Maybe.Just(inValue)
		if maybe.IsKind(reflect.Ptr) {
			ptr := maybe.ToPtr()
			if reflect.TypeOf(*ptr).Kind() == (reflect.TypeOf(CompData{}).Kind()) {
				value = *ptr
			}
		}

		if pattern.Matches(value) {
			return pattern.Apply(value)
		}
	}

	panic(fmt.Sprintf("Cannot match %v", inValue))
}

// Matches Match the given value by the pattern
func (patternSelf KindPatternDef) Matches(value interface{}) bool {
	if Maybe.Just(value).IsNil() {
		return false
	}

	return patternSelf.kind == reflect.TypeOf(value).Kind()
}

// Matches Match the given value by the pattern
func (patternSelf CompTypePatternDef) Matches(value interface{}) bool {
	if Maybe.Just(value).IsPresent() && reflect.TypeOf(value).Kind() == reflect.TypeOf(CompData{}).Kind() {
		return MatchCompType(patternSelf.compType, (value).(CompData))
	}

	return patternSelf.compType.Matches(value)
}

// Matches Match the given value by the pattern
func (patternSelf EqualPatternDef) Matches(value interface{}) bool {
	return patternSelf.value == value
}

// Matches Match the given value by the pattern
func (patternSelf RegexPatternDef) Matches(value interface{}) bool {
	if Maybe.Just(value).IsNil() || reflect.TypeOf(value).Kind() != reflect.String {
		return false
	}

	matches, err := regexp.MatchString(patternSelf.pattern, (value).(string))
	if err == nil && matches {
		return true
	}

	return false
}

// Matches Match the given value by the pattern
func (patternSelf OtherwisePatternDef) Matches(value interface{}) bool {
	return true
}

// Apply Evaluate the result by its given effect function
func (patternSelf KindPatternDef) Apply(value interface{}) interface{} {
	return patternSelf.effect(value)
}

// Apply Evaluate the result by its given effect function
func (patternSelf CompTypePatternDef) Apply(value interface{}) interface{} {
	return patternSelf.effect(value)
}

// Apply Evaluate the result by its given effect function
func (patternSelf EqualPatternDef) Apply(value interface{}) interface{} {
	return patternSelf.effect(value)
}

// Apply Evaluate the result by its given effect function
func (patternSelf RegexPatternDef) Apply(value interface{}) interface{} {
	return patternSelf.effect(value)
}

// Apply Evaluate the result by its given effect function
func (patternSelf OtherwisePatternDef) Apply(value interface{}) interface{} {
	return patternSelf.effect(value)
}

// DefPattern Define the PatternMatching by Pattern list
func DefPattern(patterns ...Pattern) PatternMatching {
	return PatternMatching{patterns: patterns}
}

// InCaseOfKind In case of its Kind matches the given one
func InCaseOfKind(kind reflect.Kind, effect fnObj) Pattern {
	return KindPatternDef{kind: kind, effect: effect}
}

// InCaseOfSumType In case of its SumType matches the given one
func InCaseOfSumType(compType CompType, effect fnObj) Pattern {
	return CompTypePatternDef{compType: compType, effect: effect}
}

// InCaseOfEqual In case of its value is equal to the given one
func InCaseOfEqual(value interface{}, effect fnObj) Pattern {
	return EqualPatternDef{value: value, effect: effect}
}

// InCaseOfRegex In case of the given regex rule matches its value
func InCaseOfRegex(pattern string, effect fnObj) Pattern {
	return RegexPatternDef{pattern: pattern, effect: effect}
}

// Otherwise In case of the other patterns didn't match it
func Otherwise(effect fnObj) Pattern {
	return OtherwisePatternDef{effect: effect}
}

// Either Match Pattern list and return the effect() result of the matching Pattern
func Either(value interface{}, patterns ...Pattern) interface{} {
	return DefPattern(patterns...).MatchFor(value)
}

// SumType

// CompData Composite Data with values & its CompType(SumType)
type CompData struct {
	compType CompType
	objects  []interface{}
}

// CompType Abstract SumType concept interface
type CompType interface {
	Matches(value ...interface{}) bool
}

// SumType SumType contains a CompType list
type SumType struct {
	compTypes []CompType
}

// ProductType ProductType with a Kind list
type ProductType struct {
	kinds []reflect.Kind
}

// NilTypeDef NilType implemented by Nil determinations
type NilTypeDef struct {
}

// Matches Check does it match the SumType
func (typeSelf SumType) Matches(value ...interface{}) bool {
	for _, compType := range typeSelf.compTypes {
		if compType.Matches(value...) {
			return true
		}
	}

	return false
}

// Matches Check does it match the ProductType
func (typeSelf ProductType) Matches(value ...interface{}) bool {
	if len(value) != len(typeSelf.kinds) {
		return false
	}

	matches := true
	for i, v := range value {
		matches = matches && typeSelf.kinds[i] == Maybe.Just(v).Kind()
	}
	return matches
}

// Matches Check does it match nil
func (typeSelf NilTypeDef) Matches(value ...interface{}) bool {
	if len(value) != 1 {
		return false
	}

	return Maybe.Just(value[0]).IsNil()
}

// DefSum Define the SumType by CompType list
func DefSum(compTypes ...CompType) CompType {
	return SumType{compTypes: compTypes}
}

// DefProduct Define the ProductType of a SumType
func DefProduct(kinds ...reflect.Kind) CompType {
	return ProductType{kinds: kinds}
}

// NewCompData New SumType Data by its type and composite values
func NewCompData(compType CompType, value ...interface{}) *CompData {
	if compType.Matches(value...) {
		return &CompData{compType: compType, objects: value}
	}

	return nil
}

// MatchCompType Check does the Composite Data match the given SumType
func MatchCompType(compType CompType, value CompData) bool {
	return MatchCompTypeRef(compType, &value)
}

// MatchCompTypeRef Check does the Composite Data match the given SumType
func MatchCompTypeRef(compType CompType, value *CompData) bool {
	return compType.Matches(value.objects...)
}

// NilType NilType CompType instance
var NilType NilTypeDef
```

使用
```go
var fn01 = func(args ...interface{}) []interface{} {
  val, _ := Maybe.Just(args[0]).ToInt()
  return SliceOf(val + 1)
}
var fn02 = func(args ...interface{}) []interface{} {
  val, _ := Maybe.Just(args[0]).ToInt()
  return SliceOf(val + 2)
}
var fn03 = func(args ...interface{}) []interface{} {
  val, _ := Maybe.Just(args[0]).ToInt()
  return SliceOf(val + 3)
}

// Result would be 6
result := Compose(fn01, fn02, fn03)((0))[0]
```



## Useful lib
[https://github.com/TeaEntityLab/fpGo](https://github.com/TeaEntityLab/fpGo)
[https://github.com/seborama/fuego](https://github.com/seborama/fuego)
[https://github.com/tobyhede/go-underscore](https://github.com/tobyhede/go-underscore)



