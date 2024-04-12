# play.zig

![play.zig](https://github.com/dgv/play.zig/blob/main/screenshot.png)

play.zig is just another Zig playground, actually an adaptation wrapping Zig for compilation and format code from my old [go-vim](https://github.com/dgv/go-vim) (Go Playground), will be rewritten using zig eventually... During my learning I miss some place to run ziglings or share code quickly, so here we go...

Following considerations when you use it:

- Runs last Zig stable version.
- 5s timeout by default.
- if firejail is installed the consumption of networking is blocked and memory limited.
- code snippets for sharing are stored locally using sqlite.

### Motivation

Another playgrounds implementations:

- [playground from zigtools](https://github.com/zigtools/playground): nice, but weird highlighting, no fmt.
- [zig-play](https://github.com/gsquire/zig-play): slow, no share option.

Related:

- [zigbin.io](https://zigbin.io/): another purpose but nice, run zig trunk version by default, can run and share local files there via curl, no fmt.
- [zig.run](https://github.com/jlauman/zig.run): nice, written in zig but offline, confused layout, no share option. give me the idea to add ziggy ;)

### Run locally with docker

```
$ docker run --rm -p 8080:8080 dgvargas/play-zig
```

### Env vars

```
PORT=<NUMBER>: port binding number [defult: 8080]
ZIG_TIMEOUT=<NUMBER>: zig timeout [default: 5]
FIREJAIL_DEBUG=<BOOL>: debug verbose [default: false]
FIREJAIL_NET=<BOOL>: network access [default: false]
FIREJAIL_RLIMIT=<NUMBER>: virtual memory allocation limit in MBs [default: 300]
SHARE_PASSTHRU_URL=<STRING>: URL for skip local sharing functionality [default: ""]
```

### Roadmap:

- [x] zig wrapping
- [x] ziglings
- [x] expose sandbox/runtime paramenters as env vars
- [ ] rewrite using zig
