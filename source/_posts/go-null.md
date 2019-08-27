---
title: GO空值最佳实践
date: 2019-08-22 09:56:12
categories: 
- Go
tags:
    - zero
---
每种语言都存在变量声明与初始化的过程，而GO也不例外，那么我们如何妥善的处理Zero问题，如结构体属性初始值问题，SQL null问题，JSON null问题（序列化问题）。

<!-- more -->

## 各类型的zero values

在GO中变量声明后不给初始化时系统给定一个Zero值，其中不同类型对应不同默认值

- 0 for all integer types,
- 0.0 for floating point numbers,
- false for booleans,
- "" for strings,
- nil for interfaces, slices, channels, maps, pointers and functions.

```go
func main() {
	var aInt int
	var aFloat float32
	var aBool bool
	var aString bool
	var aChan chan struct{}
	fmt.Println(aInt)
	fmt.Println(aFloat)
	fmt.Println(aBool)
	fmt.Println(aString)
	fmt.Println(aChan)
}
```
```sh
[Running] go run "/home/double/Work/GO/demo/tempCodeRunnerFile.go"
0
0
false
false
<nil>
```
所以在实际开发中，我们通常需要妥善区分默认值与初始值，尤其是在做IO领域类型转换时。

## 变量空值
变量区分初始值与默认值

### 统一为空值处理

```go
// ISBlank defined check value is blank or not
func ISBlank(value reflect.Value) bool {
	switch value.Kind() {
	case reflect.String:
		return value.Len() == 0
	case reflect.Bool:
		return !value.Bool()
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return value.Int() == 0
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64, reflect.Uintptr:
		return value.Uint() == 0
	case reflect.Float32, reflect.Float64:
		return value.Float() == 0
	case reflect.Interface, reflect.Ptr:
		return value.IsNil()
	}
	return reflect.DeepEqual(value.Interface(), reflect.Zero(value.Type()).Interface())
}
func main() {
	var aInt int
	fmt.Println(ISBlank(reflect.ValueOf(aInt)))
}
```

### 巧妙利用nil类型

用指针过度
```go
func main() {
	var aInt *int
	fmt.Println(aInt)

	aInt = new(int)
	fmt.Println(*aInt)
}
```
```sh
[Running] go run "/home/double/Work/GO/demo/tempCodeRunnerFile.go"
<nil>
0
```

指针取地址注意事项

`The Go Language Specification (Address operators) does not allow to take the address of a numeric constant (not of an untyped nor of a typed constant).`

友情链接：
[https://stackoverflow.com/questions/30716354/how-do-i-do-a-literal-int64-in-go](https://stackoverflow.com/questions/30716354/how-do-i-do-a-literal-int64-in-go)

用结构体过度
```go
type nullInt struct {
	value   int
	isValid bool
}
func main() {
	a := nullInt{value: 12, isValid: true}
	if a.isValid {
		fmt.Println(a.value)
	}
}
```
```sh
[Running] go run "/home/double/Work/GO/demo/tempCodeRunnerFile.go"
12
```
## 结构体属性空值
### 用指针过度
```go
// User defined user info
type User struct {
	Name    string
	Age     int
	Address *string
}
```
### 用结构体过度 
```go
// User defined user info
type User struct {
	Name    string
	Age     int
	Address struct {
        Value string
        Valid bool
    }
}
```
## 结构体序列化
其实在非IO程序上处理空值，基本使用ISBlank的满足大部分需求的，但是在IO时就存在很多问题，GO跟其他语言交互时，如映射JSON，映射SQL

### JSON属性空值

- 使用interface{}接受值类型
```go
func main() {
	const jsonData = `
    {"Name": "Alice", "Age": 25, "Address": null }
    {"Name": "Bob", "Age": 22, "Address": "GZ" }`
	reader := strings.NewReader(jsonData)
	writer := os.Stdout
	dec := json.NewDecoder(reader)
	enc := json.NewEncoder(writer)
	for {
		var m map[string]interface{}
		if err := dec.Decode(&m); err == io.EOF {
			break
		} else if err != nil {
			log.Fatal(err)
		}
		for k := range m {
			if k == "Age" {
				delete(m, k)
			}
		}
		if err := enc.Encode(&m); err != nil {
			log.Println(err)
		}
	}
}
```
如上面我们Address有null和string类型，这两个类型在go是不允许同时存在string中的，我们使用interface{}来接受就处理了，不过要返回实际的值，我们还得断言一次

- 指针取地址
```go
// User defined user info
type User struct {
	Name    string
	Age     int
	Address *string
}
```
- 实现Jsoner interface
我们可以通过实现Jsoner interface然后在对应的函数做处理`打标记`

```go
type Jsoner interface {
    UnmarshalJSON(data []byte) error 
    MarshalJSON() ([]byte, error)
}
```

Example:
```go
type NullString struct {
	String string
	Valid  bool
}

func (s *NullString) UnmarshalJSON(data []byte) error {
	var err error
	var v interface{}
	if err = json.Unmarshal(data, &v); err != nil {
		return err
	}
	switch x := v.(type) {
	case string:
		s.String = x
	case map[string]interface{}:
		err = json.Unmarshal(data, &s.NullString)
	case nil:
		s.Valid = false
		return nil
	default:
		err = fmt.Errorf("json: cannot unmarshal %v into Go value of type null.String", reflect.TypeOf(v).Name())
	}
	s.Valid = err == nil
	return err
}

func (s NullString) MarshalJSON() ([]byte, error) {
	if !s.Valid {
		return []byte("null"), nil
	}
	return json.Marshal(s.String)
}

```

### SQL属性空值

- 使用interface{}接受值类型 `参考上面`

- 指针取地址 `参考上面`

实现Scanner interface.
```go
type Scaner interface {
    Scan(value interface{}) error
    Value() (driver.Value, error)
}
```

Example:
```go
type NullString struct {
	String string
	Valid  bool
}
func (ns *NullString) Scan(value interface{}) error {
	if value == nil {
		ns.String, ns.Valid = "", false
		return nil
	}
	ns.Valid = true
	return convertAssign(&ns.String, value)
}
func (ns NullString) Value() (driver.Value, error) {
	if !ns.Valid {
		return nil, nil
	}
	return ns.String, nil
}
```
其实不管是JSON还是SQL本质处理还是一样的

## 统一处理方案

在实际的开发应用中我们整个逻辑都是围绕着三个场景下去解决空值问题

- JSON <=> GO
- SQL  <=> GO
- JSON <=> SQL

处理空值的原理就在序列化和反序列化时做同步的处理。

对于SQL需要实现接口
```go
type Scaner interface {
    Scan(value interface{}) error
    Value() (driver.Value, error)
}
```
对于JSON需要实现接口

```go
type Jsoner interface {
    UnmarshalJSON(data []byte) error 
    MarshalJSON() ([]byte, error)
}
```

如果还有其他标准，直接实现即可，如：
```go
type Texter interface {
    UnmarshalText(text []byte) error
    MarshalText() ([]byte, error)
}
```

如果手动处理这些问题有点麻烦，我们这里使用一个成熟的lib来处理序列化时要处理的空值问题。

[https://github.com/guregu/null](https://github.com/guregu/null)

### null package

Will marshals to JSON null if SQL source data is null. Zero (blank) input will not produce a null `XXX`. Can unmarshal from sql.Null`XXX` JSON input or `XXX` input.

使用之前由于Address是null不处理，反序列化后Address被给定空字符串，再次序列化后就存在问题了，null变成''
```go
// User defined user info
type User struct {
	Name    string
	Age     int
	Address string
}

func main() {
	const jsonData = `
    {"Name": "Alice", "Age": 25, "Address": null }
    {"Name": "Bob", "Age": 22, "Address": "GZ" }`
	reader := strings.NewReader(jsonData)
	writer := os.Stdout
	dec := json.NewDecoder(reader)
	enc := json.NewEncoder(writer)
	for {
		var u User
		if err := dec.Decode(&u); err == io.EOF {
			break
		} else if err != nil {
			log.Fatal(err)
		}
		if err := enc.Encode(&u); err != nil {
			log.Println(err)
		}
	}
}
```
```sh
[Running] go run "/home/double/Work/K11/GO/demo/tempCodeRunnerFile.go"
{"Name":"Alice","Age":25,"Address":""}
{"Name":"Bob","Age":22,"Address":"GZ"}
```

修改成null.String
```go
// User defined user info
type User struct {
	Name    string
	Age     int
	Address null.String
}

func main() {
	const jsonData = `
    {"Name": "Alice", "Age": 25, "Address": null }
    {"Name": "Bob", "Age": 22, "Address": "GZ" }`
	reader := strings.NewReader(jsonData)
	writer := os.Stdout
	dec := json.NewDecoder(reader)
	enc := json.NewEncoder(writer)
	for {
		var u User
		if err := dec.Decode(&u); err == io.EOF {
			break
		} else if err != nil {
			log.Fatal(err)
		}
		fmt.Println(u.Address.Valid)
		if err := enc.Encode(&u); err != nil {
			log.Println(err)
		}
	}
}
```
```sh
[Running] go run "/home/double/Work/K11/GO/demo/tempCodeRunnerFile.go"
false
{"Name":"Alice","Age":25,"Address":null}
true
{"Name":"Bob","Age":22,"Address":"GZ"}
```

### zero package

Will marshal to a blank `XXX` if null. Blank `XXX` input produces a null `XXX`. Null values and zero values are considered equivalent. Can unmarshal from sql.Null`XXX` JSON input.

如果为null则输出默认值，我们可以通过zero.String实现
```go
// User defined user info
type User struct {
	Name    string
	Age     int
	Address zero.String
}

func main() {
	const jsonData = `
    {"Name": "Alice", "Age": 25, "Address": null }
    {"Name": "Bob", "Age": 22, "Address": "GZ" }`
	reader := strings.NewReader(jsonData)
	writer := os.Stdout
	dec := json.NewDecoder(reader)
	enc := json.NewEncoder(writer)
	for {
		var u User
		if err := dec.Decode(&u); err == io.EOF {
			break
		} else if err != nil {
			log.Fatal(err)
		}
		fmt.Println(u.Address.Valid)
		if err := enc.Encode(&u); err != nil {
			log.Println(err)
		}
	}
}
```
```sh
[Running] go run "/home/double/Work/K11/GO/demo/tempCodeRunnerFile.go"
false
{"Name":"Alice","Age":25,"Address":""}
true
{"Name":"Bob","Age":22,"Address":"GZ"}
```