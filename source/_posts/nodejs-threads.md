---
title: Nodejs多线程使用
date: 2019-09-02 09:58:49
categories: 
- Nodejs
tags:
    - threads
---

作为一个单线程的Nodejs，虽然底层使用内核多线程技术处理IO，但是对于main事件轮循处理都是单线程的，如果是CPU密集操作将会导致事件饥饿，笔者在开发时也常经常遇到。

<!-- more -->

## Worker threads

worker threads是Node.js v10.5.0引进的技术，目前还处于Experimental，这个对于用还是不用（笔者推荐使用，如果你来到了这里，说明你遇到threads来解决CPU密集的业务）

### NVM 切换版本
使用最近一个稳定版本的, 并且要包含worker threads，也就是v10.5.0+
```sh
nvm ls-remote
nvm install v10.16.3
nvm use v10.16.3
```
### new Worker
调用Worker后，当前上下代码会被重新在另一个线程执行，而且数据只能通过workerData传递过去(QAQ, 这不是linux的进程切换？)，所以我们只能把这个threads隔离到module去实现。。。

cacTwo.js
```javascript
const {
    Worker, isMainThread, parentPort, workerData
} = require('worker_threads');

function cacTwo({ a, b }) {
    var i = 0
    while(i < 1000000000) {
        i ++
    }
    return a + b
}

if (isMainThread) {
    module.exports = function (script) {
        return new Promise((resolve, reject) => {
            const worker = new Worker(__filename, {
                workerData: script
            });
            worker.on('message', resolve);
            worker.on('error', reject);
            worker.on('exit', (code) => {
                if (code !== 0)
                    reject(new Error(`Worker stopped with exit code ${code}`));
            });
        });
    };
} else {
    parentPort.postMessage(cacTwo(workerData));
}
```

main.js
```javascript
const cacTwo = require('./cacTwo')
cacTwo({a: 12, b: 10}).then(x => {
    console.log(x)
})
```

```sh
node --experimental-worker main.js
```

更多的细节，以及操作函数, 参考
[https://nodejs.org/api/worker_threads.html](https://nodejs.org/api/worker_threads.html)

## Worker pool

为了避免频繁new Worker创建线程而造成切换上下文的损耗，我们可以通过poll方式管理worker，从而避免反复创建和销毁worker

```sh
npm install worker-threads-pool --save
```

cacTwo.js
```sh
const Pool = require('worker-threads-pool')
const pool = new Pool({max: 10})

const {
    Worker, isMainThread, parentPort, workerData
} = require('worker_threads');

function cacTwo({ a, b }) {
    var i = 0
    while(i < 1000000000) {
        i ++
    }
    return a + b
}

if (isMainThread) {
    console.log('cache')
    module.exports = function (i, script) {
        return new Promise((resolve, reject) => {
            pool.acquire(__filename, {workerData: script}, function (err, worker) {
                if (err) throw err
                console.log(`started worker ${i} (pool size: ${pool.size})`)
                worker.on('message', resolve);
                worker.on('error', reject);
                worker.on('exit', (code) => {
                    if (code !== 0)
                        reject(new Error(`Worker stopped with exit code ${code}`));
                });
              })
        });
    };
} else {
    parentPort.postMessage(cacTwo(workerData));
}
```

main.js
```sh

const cacTwo = require('./cacTwo')

for (let i = 0; i < 100; i++) {
    cacTwo(i, {a: 12, b: 10}).then(x => {
        console.log(x)
    })
}
```