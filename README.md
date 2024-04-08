# play.zig

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/dgv/play.zig)

![play.zig](https://github.com/dgv/play.zig/blob/main/screenshot.png)

play.zig is just another Zig playground, actually an adaptation wrapping zig executable for compilation and format code from my old [go-vim](https://github.com/dgv/go-vim) (Go Playground), will be rewritten using zig eventually... During my learning I miss some place to run ziglings or share code quickly, so here we go...

Following considerations when you use it:

- 5s timeout by default.
- if firejail is installed the consumption of networking is blocked and memory limited (10MB per execution).
- code snippets for sharing are stored locally using sqlite.

### Motivation

Another playgrounds implementations:

- [playground from zigtools](https://github.com/zigtools/playground): nice, but weird syntax hilighting and no fmt.
- [zig-play](https://github.com/gsquire/zig-play): slow, no share option.
- [zig.run](https://github.com/jlauman/zig.run): nice, written in zig but offline, confused layout, no share option. give me the idea to add ziggy ;)

### Roadmap:

- [x] zig wrapping
- [x] ziglings
- [ ] add local installation instructions here
- [ ] fiz firejail memory limitation (rlimit is not working for some reason)
- [ ] expose sandbox/runtime paramenters as env vars
- [ ] rewrite using zig
