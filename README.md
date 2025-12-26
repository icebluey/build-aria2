# build-aria2
```
#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
exec /opt/aria2/bin/aria2c -s 16 -j 16 -x 16 -c --file-allocation=falloc --seed-time=0 "$@"
exit
```
