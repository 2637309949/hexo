---
title: Nodejs Promis设计
date: 2019-08-18 21:04:52
categories: 
- Nodejs
tags:
    - promise
---
一开始接触Nodejs时，我很纳闷异步发生的具体过程，而我在网上找的资料很多都很粗略，什么CB异步操作（让人误解）...，其实理解深入理解Nodejs事件后才知道异步产生是在Nodejs的事件循环中发生的(setTimeout或其他api)，具体可以看我整理的一片文章`Nodejs 深入事件循环`，这里我们整理一篇如何实现Promise的文章。
<!-- more -->

## State `machine`
由于promise只是一个状态`machine`，我们应该首先考虑以后需要的状态信息。

```javascript
var PENDING = 0;
var FULFILLED = 1;
var REJECTED = 2;

function Promise() {
  // store state which can be PENDING, FULFILLED or REJECTED
  var state = PENDING;

  // store value or error once FULFILLED or REJECTED
  var value = null;

  // store sucess & failure handlers attached by calling .then or .done
  var handlers = [];
}
```

## Transitions
接下来，让我们考虑可能发生的状态`完成`和`拒绝`的两个关键转换：

```javascript
var PENDING = 0;
var FULFILLED = 1;
var REJECTED = 2;

function Promise() {
  // store state which can be PENDING, FULFILLED or REJECTED
  var state = PENDING;

  // store value once FULFILLED or REJECTED
  var value = null;

  // store sucess & failure handlers
  var handlers = [];

  function fulfill(result) {
    state = FULFILLED;
    value = result;
  }

  function reject(error) {
    state = REJECTED;
    value = error;
  }
}
```

这为我们提供了基本的低级转换，但让我们考虑一个额外的，更高级别的转换 resolve


```javascript
var PENDING = 0;
var FULFILLED = 1;
var REJECTED = 2;

function Promise() {
  // store state which can be PENDING, FULFILLED or REJECTED
  var state = PENDING;

  // store value once FULFILLED or REJECTED
  var value = null;

  // store sucess & failure handlers
  var handlers = [];

  function fulfill(result) {
    state = FULFILLED;
    value = result;
  }

  function reject(error) {
    state = REJECTED;
    value = error;
  }

  function resolve(result) {
    try {
      var then = getThen(result);
      if (then) {
        doResolve(then.bind(result), resolve, reject)
        return
      }
      fulfill(result);
    } catch (e) {
      reject(e);
    }
  }
}
```

注意resolve如何接受promise或plain值，如果是promise，则等待它完成。promise绝不能用另一个promise来实现，所以resolve我们将公开这个功能，而不是内部fulfill。我们使用了几个辅助方法，所以我们定义一下：

```javascript
/**
 * Check if a value is a Promise and, if it is,
 * return the `then` method of that promise.
 *
 * @param {Promise|Any} value
 * @return {Function|Null}
 */
function getThen(value) {
  var t = typeof value;
  if (value && (t === 'object' || t === 'function')) {
    var then = value.then;
    if (typeof then === 'function') {
      return then;
    }
  }
  return null;
}

/**
 * Take a potentially misbehaving resolver function and make sure
 * onFulfilled and onRejected are only called once.
 *
 * Makes no guarantees about asynchrony.
 *
 * @param {Function} fn A resolver function that may not be trusted
 * @param {Function} onFulfilled
 * @param {Function} onRejected
 */
function doResolve(fn, onFulfilled, onRejected) {
  var done = false;
  try {
    fn(function (value) {
      if (done) return
      done = true
      onFulfilled(value)
    }, function (reason) {
      if (done) return
      done = true
      onRejected(reason)
    })
  } catch (ex) {
    if (done) return
    done = true
    onRejected(ex)
  }
}
```
## Constructing

我们现在已经完成了内部状态`machine`，但我们尚未公开解决promise或观察它的方法。让我们首先添加一种解决promise的方法。

```javascript
var PENDING = 0;
var FULFILLED = 1;
var REJECTED = 2;

function Promise(fn) {
  // store state which can be PENDING, FULFILLED or REJECTED
  var state = PENDING;

  // store value once FULFILLED or REJECTED
  var value = null;

  // store sucess & failure handlers
  var handlers = [];

  function fulfill(result) {
    state = FULFILLED;
    value = result;
  }

  function reject(error) {
    state = REJECTED;
    value = error;
  }

  function resolve(result) {
    try {
      var then = getThen(result);
      if (then) {
        doResolve(then.bind(result), resolve, reject)
        return
      }
      fulfill(result);
    } catch (e) {
      reject(e);
    }
  }

  doResolve(fn, resolve, reject);
}
```
如您所见，我们重新使用，doResolve因为我们有另一个不受信任的解析器。该fn允许都调用resolve和reject多次，甚至抛出异常。我们有责任确保承诺只被解决或拒绝一次，然后再也不会转变为不同的状态。

## Observing (via .done)

我们现在有一个完整的状态机，但我们仍无法观察它的任何变化。我们的最终目标是实现.then，但语义.done更简单，所以首先要实现它。

我们的目标是实现以下目标promise.done(onFulfilled, onRejected)：

- 只有一个onFulfilled或onRejected被调用
- 它只被调用一次
- 直到下一个tick（即.done方法返回后）才会调用它
- 无论在我们调用之前或之后是否解决了promise，都会调用它 .done

```javascript
var PENDING = 0;
var FULFILLED = 1;
var REJECTED = 2;

function Promise(fn) {
  // store state which can be PENDING, FULFILLED or REJECTED
  var state = PENDING;

  // store value once FULFILLED or REJECTED
  var value = null;

  // store sucess & failure handlers
  var handlers = [];

  function fulfill(result) {
    state = FULFILLED;
    value = result;
    handlers.forEach(handle);
    handlers = null;
  }

  function reject(error) {
    state = REJECTED;
    value = error;
    handlers.forEach(handle);
    handlers = null;
  }

  function resolve(result) {
    try {
      var then = getThen(result);
      if (then) {
        doResolve(then.bind(result), resolve, reject)
        return
      }
      fulfill(result);
    } catch (e) {
      reject(e);
    }
  }

  function handle(handler) {
    if (state === PENDING) {
      handlers.push(handler);
    } else {
      if (state === FULFILLED &&
        typeof handler.onFulfilled === 'function') {
        handler.onFulfilled(value);
      }
      if (state === REJECTED &&
        typeof handler.onRejected === 'function') {
        handler.onRejected(value);
      }
    }
  }

  this.done = function (onFulfilled, onRejected) {
    // ensure we are always asynchronous
    setTimeout(function () {
      handle({
        onFulfilled: onFulfilled,
        onRejected: onRejected
      });
    }, 0);
  }

  doResolve(fn, resolve, reject);
}
```
我们确保在解决或拒绝Promise时通知处理程序。我们只会在下一个tick执行此操作。

## Observing (via .then)
现在我们已经.done实现了，我们可以很容易地实现.then同样的事情，但在这个过程中构建一个新的Promise。

```javascript
this.then = function (onFulfilled, onRejected) {
  var self = this;
  return new Promise(function (resolve, reject) {
    return self.done(function (result) {
      if (typeof onFulfilled === 'function') {
        try {
          return resolve(onFulfilled(result));
        } catch (ex) {
          return reject(ex);
        }
      } else {
        return resolve(result);
      }
    }, function (error) {
      if (typeof onRejected === 'function') {
        try {
          return resolve(onRejected(error));
        } catch (ex) {
          return reject(ex);
        }
      } else {
        return reject(error);
      }
    });
  });
}
```


参考链接
[https://www.promisejs.org/implementing](https://www.promisejs.org/implementing)



