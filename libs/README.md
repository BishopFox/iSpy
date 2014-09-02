iSpy needs these libraries in order to build. They are all distributed as pre-compiled libraries as part of the iSpy git repo, but if you really want to build them yourself here's how to do it.

CocoaHTTPServer.a
-----------------------
This is a git submodule. Actual repo: https://github.com/moloch--/CocoaHTTPServer
To build:

```
cd iSpyServer/CocoaHTTPServer
./build.sh
```

That's it. iSpy knows where to find the resulting library. No further action required :)

