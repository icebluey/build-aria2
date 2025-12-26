```
#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
exec /opt/aria2/bin/aria2c -s 16 -j 16 -x 16 -c --file-allocation=falloc --seed-time=0 "$@"
exit
```

# convert magnet link to torrent file
```
aria2c --bt-metadata-only=true --bt-save-metadata=true 'magnet:?xt=urn:btih:sha1hash'
```

# print file listing of ".torrent"
```
aria2c -S filename.torrent
```

# set  file  to download by specifying its index
```
aria2c --select-file=1-5,8,9 filename.torrent
```
