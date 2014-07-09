## Luawa + Nginx (4 workers)

```
$ wrk -c 30 -d 20s -t 4 http://localhost:5000
Running 20s test @ http://localhost:5000
  4 threads and 30 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.44ms    6.45ms  94.80ms   99.50%
    Req/Sec     7.45k     1.47k   14.00k    73.76%
  560819 requests in 20.00s, 212.84MB read
Requests/sec:  28040.71
Transfer/sec:     10.64MB
```


## Luawa + Nginx (1 worker)

```
$ wrk -c 30 -d 20s -t 4 http://localhost:5000
Running 20s test @ http://localhost:5000
  4 threads and 30 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.95ms  839.95us  23.39ms   96.75%
    Req/Sec     3.86k   494.09     4.67k    79.33%
  292980 requests in 20.00s, 111.19MB read
Requests/sec:  14649.06
Transfer/sec:      5.56MB
```


## Node

```
$ wrk -c 30 -d 20s -t 4 http://localhost:8080
Running 20s test @ http://localhost:8080
  4 threads and 30 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.67ms  366.55us  11.14ms   94.45%
    Req/Sec     4.46k   476.14     5.33k    83.34%
  338286 requests in 20.00s, 47.10MB read
Requests/sec:  16914.69
Transfer/sec:      2.36MB
```
