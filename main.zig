const std = @import("std");
const s3db = @import("s3db");
const httpz = @import("httpz");
const zmpl = @import("zmpl");
const zcmd = @import("zcmd");
const tmp = @import("tmpfile");
const string = @import("string");
const Collator = @import("ziglyph").Collator;

const max_snippet_size = 64 * 1024;
const gpa = global.allocator();
const bufsize = 8196;
const salt = "Zig playground salt\n";
const hello =
    \\const std = @import("std");
    \\const builtin = @import("builtin");
    \\
    \\pub fn main() !void {
    \\    std.debug.print("Hello from Zig {}", .{builtin.zig_version});
    \\}
    \\
;

var global = std.heap.GeneralPurposeAllocator(.{}){};
var db: s3db.Db = undefined;
var ziglings_list = std.ArrayList(u8).init(gpa);

fn loadZiglings(alloc: std.mem.Allocator, zigling: []const u8) !void {
    var collator = try Collator.init(alloc);
    defer collator.deinit();
    var temp = std.ArrayList([]u8).init(alloc);
    defer temp.deinit();

    _ = try ziglings_list.toOwnedSlice();
    var dir = std.fs.cwd().openDir("ziglings/exercises", .{ .iterate = true }) catch |e| switch (e) {
        error.FileNotFound => {
            std.debug.print("ziglings dir not found\n", .{});
            return;
        },
        else => unreachable,
    };
    var it = dir.iterate();
    while (try it.next()) |file| {
        if (file.kind != .file) {
            continue;
        }
        const html = try std.fmt.allocPrint(
            alloc,
            "<option value=\"{s}\" {s}>{s}</option>",
            .{ file.name, if (std.mem.eql(u8, file.name, zigling)) "selected" else "", file.name },
        );
        try temp.append(html);
    }

    std.mem.sort([]u8, temp.items, collator, Collator.ascendingCaseless);
    for (temp.items) |t| {
        try ziglings_list.appendSlice(try alloc.dupe(u8, t));
    }
}

pub fn main() !void {
    defer ziglings_list.deinit();
    // parse env
    const addr = std.process.getEnvVarOwned(gpa, "ADDR") catch "0.0.0.0";
    const port = try std.fmt.parseUnsigned(u16, std.process.getEnvVarOwned(gpa, "PORT") catch "3000", 10);
    // init db
    try initDb();
    defer db.deinit();
    // server config
    var server = try httpz.Server().init(gpa, .{ .address = addr, .port = port, .request = .{
        .max_form_count = 4,
    } });
    // routes
    var router = server.router();
    router.get("/", edit);
    router.get("/p/:snippet", edit);
    router.get("/static/*", static);
    router.post("/compile", run);
    router.post("/fmt", run);
    router.post("/share", share);
    router.get("/metrics", metrics);
    // init server
    std.log.info("listening at {s}:{d}", .{ addr, port });
    try server.listen();
}

fn edit(req: *httpz.Request, res: *httpz.Response) !void {
    var timer = try std.time.Timer.start();
    defer {
        const elapsed = timer.lap() / 1000;
        std.log.info("{any} {d} {s} from {any} {d}ms", .{ req.method, res.status, req.url.raw, req.address, elapsed });
    }
    var content: []const u8 = hello;
    // /p/<snippet id>
    const snippet = req.param("snippet") orelse "";
    if (!std.mem.eql(u8, snippet, "")) {
        content = get(snippet) catch {
            res.status = 404;
            res.body = "Snippet not found";
            return;
        };
    }
    const query = try req.query();
    const zigling = query.get("zigling") orelse "";

    if (!std.mem.eql(u8, zigling, "")) {
        try loadZiglings(req.arena, zigling);
        const path = try std.fmt.allocPrint(req.arena, "./ziglings/exercises/{s}", .{zigling});
        var file = std.fs.cwd().openFile(path, .{}) catch {
            res.status = 404;
            res.body = "Zigling not found";
            return;
        };
        content = try file.reader().readAllAlloc(req.arena, max_snippet_size);
        defer file.close();
    } else {
        try loadZiglings(req.arena, zigling);
    }

    var d = zmpl.Data.init(res.arena);
    defer d.deinit();
    var root = try d.root(.object);

    try root.put("snippet", content);
    try root.put("ziglings", ziglings_list.items);
    if (zmpl.find("edit")) |template| {
        const body = try template.render(&d);
        res.body = body;
        res.content_type = .HTML;
    }
}

fn static(req: *httpz.Request, res: *httpz.Response) !void {
    var timer = try std.time.Timer.start();
    defer {
        const elapsed = timer.lap() / 1000;
        std.log.info("{any} {d} {s} from {any} {d}ms", .{ req.method, res.status, req.url.raw, req.address, elapsed });
    }
    const asset = std.fs.path.basename(req.url.raw);
    const path = try std.fmt.allocPrint(req.arena, ".{s}", .{req.url.raw});
    var file = std.fs.cwd().openFile(path, .{}) catch {
        res.status = 404;
        res.body = "Not found";
        return;
    };
    const content = try file.reader().readAllAlloc(req.arena, 102400);
    defer req.arena.free(content);
    defer file.close();
    res.content_type = httpz.ContentType.forFile(asset);
    res.body = try req.arena.dupe(u8, content);
}

fn isUnreserved(c: u8) bool {
    return switch (c) {
        ':', ',', '?', '#', '[', ']', '@' => true,
        '!', '$', '&', '\'', '(', ')', '*', '+', ';', '=' => true,
        'A'...'Z', 'a'...'z', '0'...'9', '-', '.', '_', '~' => true,
        '/', ' ' => true,
        else => false,
    };
}

fn run(req: *httpz.Request, res: *httpz.Response) !void {
    var timer = try std.time.Timer.start();
    defer {
        const elapsed = timer.lap() / 1000;
        std.log.info("{any} {d} {s} from {any} {d}ms", .{ req.method, res.status, req.url.raw, req.address, elapsed });
    }
    var f: output = undefined;
    const b = try req.formData();
    const code = b.get("body") orelse "";
    const isFmt = std.mem.containsAtLeast(u8, req.url.raw, 1, "fmt");
    f = try if (isFmt) runFmt(req.arena, code) else runCompile(req.arena, code);
    var temp = std.ArrayList(u8).init(req.arena);
    defer temp.deinit();
    if (!std.mem.eql(u8, f.stderr, "")) {
        var splitAllStr = try string.String.init_with_contents(
            req.arena,
            f.stderr,
        );
        const a = try splitAllStr.lines();
        if (a.len > 1) {
            splitAllStr = a[0];
        }
        _ = try splitAllStr.replace(".zig", "prog.zig");
        _ = try splitAllStr.replace("<stdin>", "prog.zig");
        const idx = splitAllStr.find("prog.zig") orelse 0;
        defer splitAllStr.deinit();
        try std.Uri.Component.percentEncode(temp.writer(), splitAllStr.str()[idx..splitAllStr.len()], isUnreserved);
    }
    const out = temp.items;
    if (isFmt) {
        try res.json(.{ .Error = out, .Body = f.stdout }, .{});
    } else {
        try res.json(.{ .Errors = out, .Events = .{ .Message = f.stdout, .Kind = "stdout", .Delay = 0 }, .VetErrors = "" }, .{});
    }
}

fn share(req: *httpz.Request, res: *httpz.Response) !void {
    var timer = try std.time.Timer.start();
    defer {
        const elapsed = timer.lap() / 1000;
        std.log.info("{any} {d} {s} from {any} {d}ms", .{ req.method, res.status, req.url.raw, req.address, elapsed });
    }
    const code = req.body() orelse "";
    const id = try snippetId(code);
    try put(id, code);
    res.body = id;
    res.content_type = .TEXT;
}

fn metrics(req: *httpz.Request, res: *httpz.Response) !void {
    var timer = try std.time.Timer.start();
    defer {
        const elapsed = timer.lap() / 1000;
        std.log.info("{any} {d} {s} from {any} {d}ms", .{ req.method, res.status, req.url.raw, req.address, elapsed });
    }
    res.content_type = .TEXT;
    return httpz.writeMetrics(res.writer());
}

const output = struct {
    stdout: []const u8,
    stderr: []const u8,
};

pub fn runFmt(alloc: std.mem.Allocator, code: []const u8) !output {
    const result = try zcmd.run(.{
        .allocator = alloc,
        .commands = &[_][]const []const u8{
            &.{ "zig", "fmt", "--stdin" },
        },
        .stdin_input = code,
    });
    defer result.deinit();
    const out = try alloc.dupe(u8, result.stdout orelse "");
    var ido = out.len;
    if (out.len > 1024) ido = 1024;
    const err = try alloc.dupe(u8, result.stderr orelse "");
    var ide = err.len;
    if (err.len > 1024) ide = 1024;
    return output{ .stdout = out[0..ido], .stderr = err[0..ide] };
}

pub fn runCompile(alloc: std.mem.Allocator, code: []const u8) !output {
    var tmp_file = try tmp.tmpFile(.{ .sufix = ".zig" });
    defer tmp_file.deinit();
    try tmp_file.f.writeAll(code);
    try tmp_file.f.seekTo(0);
    var buf: [max_snippet_size]u8 = undefined;
    _ = try tmp_file.f.readAll(&buf);
    const result = try zcmd.run(.{
        .allocator = alloc,
        .commands = &[_][]const []const u8{
            &.{ "timeout", "5s", "zig", "run", tmp_file.abs_path },
        },
    });
    defer result.deinit();
    return output{ .stdout = try alloc.dupe(u8, result.stdout orelse ""), .stderr = try alloc.dupe(u8, result.stderr orelse "") };
}

fn snippetId(body: []const u8) ![]const u8 {
    var hash: [32]u8 = undefined;
    var sha256 = std.crypto.hash.sha2.Sha256.init(.{});
    sha256.update(salt);
    sha256.update(body);
    sha256.final(hash[0..]);
    const base64 = std.base64.Base64Encoder.init(std.base64.url_safe_alphabet_chars, null);
    var out_buf: [64]u8 = undefined;
    const encoded = base64.encode(&out_buf, &hash);
    var hashLen: usize = 11;
    while (hashLen <= encoded.len and encoded[hashLen - 1] == '_') {
        hashLen += 1;
    }
    return try gpa.dupe(u8, encoded[0..hashLen]);
}

fn initDb() !void {
    const s3bucket = std.process.getEnvVarOwned(gpa, "AWS_BUCKET_NAME_S3") catch "play-zig";
    const s3endpoint = std.process.getEnvVarOwned(gpa, "AWS_ENDPOINT_URL_S3") catch "";
    db = try s3db.init(.{
        .mode = s3db.Db.Mode{ .Memory = {} },
        .open_flags = .{ .write = true },
    });

    if (!std.mem.eql(u8, s3endpoint, "")) {
        try db.exec("create virtual table if not exists snippets using s3db (s3_endpoint=$s3endpoint{[]const u8}, s3_bucket=$s3bucket{[]const u8}, s3_prefix='snippets', columns='key text primary key, value text')", .{}, .{ .s3endpoint = s3endpoint, .s3bucket = s3bucket });
    } else {
        try db.exec("create table if not exists snippets (key text primary key, value text)", .{}, .{});
    }
}

fn put(id: []const u8, code: []const u8) !void {
    return try db.exec("insert or replace into snippets(key, value) values($key{[]const u8}, $value{[]const u8})", .{}, .{ .key = id, .value = code });
}

fn get(id: []const u8) ![]const u8 {
    const kv = struct {
        key: []const u8,
        value: []const u8,
    };
    const code = try db.oneAlloc(kv, std.heap.page_allocator, "select id from user where key = $key{[]const u8}", .{}, .{
        .key = id,
    });
    return if (code) |v| v.value else "";
}
