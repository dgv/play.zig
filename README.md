# play.zig
[![zig version](https://img.shields.io/badge/0.14.0-orange?style=flat&logo=zig&label=Zig&color=%23eba742)](https://ziglang.org/download/)
[![zon deps](https://img.shields.io/badge/deps%20-7-orange?color=%23eba742)](https://github.com/dgv/play.zig/blob/main/build.zig.zon)
[![build](https://github.com/dgv/play.zig/actions/workflows/build.yml/badge.svg)](https://github.com/dgv/play.zig/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

![play.zig](https://github.com/dgv/play.zig/blob/main/screenshot.png)

play.zig is just another Zig playground, actually an adaptation wrapping Zig for compilation and format code from my old [go-vim](https://github.com/dgv/go-vim) (Go Playground)...

Following considerations when you use it:

- Running at last Zig stable version.
- 5s timeout by default.
- if firejail is installed networking is sandboxed.
- code snippets for sharing are stored using sqlite.

### Motivation

During my learning I miss some place to run [ziglings](https://codeberg.org/ziglings/exercises/) or share code quickly, so here we go. Another playgrounds implementations:

- [playground from zigtools](https://github.com/zigtools/playground): nice, but weird highlighting, no fmt.
- [zig-play](https://github.com/gsquire/zig-play): slow, no share option.

Related:

- [zigbin.io](https://zigbin.io/): another purpose but nice, run zig trunk version by default, can run and share local files there via curl, no fmt.
- [zig.run](https://github.com/jlauman/zig.run): nice, written in zig but offline, confused layout, no share option. give me the idea to add ziggy ;)

### Run locally with docker

```bash
docker run --rm -p 8080:8080 dgvargas/play-zig
```

### Run locally from the source
```bash
git clone https://github.com/dgv/play.zig; cd play.zig
zig build run
```

### Env vars

```
ADDR Binding Address (default: 0.0.0.0)
PORT port binding number (defult: 8080)
AWS_ENDPOINT_URL_S3 endpoint of s3 to persist sqlite database (default: "")
AWS_BUCKET_NAME_S3 bucket name of s3 to persist sqlite database (default: "play-zig")
```
_Note: regarding s3 persistence credentials variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION and include project dir on LD_LIBRARY_PATH) must be set to work properly._
