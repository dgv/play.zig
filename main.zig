const std = @import("std");
const s3db = @import("s3db");
const httpz = @import("httpz");
const zmpl = @import("zmpl");
const zcmd = @import("zcmd");
const tmp = @import("tmpfile");
const ziglyph = @import("ziglyph");

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
;

var global = std.heap.GeneralPurposeAllocator(.{}){};
var db: s3db.Db = undefined;
var ziglings_list = std.ArrayList(u8).init(std.heap.page_allocator);

fn loadZiglings() !void {
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
            gpa,
            "<option value=\"{s}\">{s}</option>",
            //.{ gpa.dupe(u8, file.name), gpa.dupe(u8, file.name) },
            .{ file.name, file.name },
        );
        try ziglings_list.appendSlice(html);
    }
}

pub fn main() !void {
    defer ziglings_list.deinit();
    try loadZiglings();
    // parse env
    const addr = std.process.getEnvVarOwned(gpa, "ADDR") catch "0.0.0.0";
    const port = try std.fmt.parseUnsigned(u16, std.process.getEnvVarOwned(gpa, "PORT") catch "3000", 10);
    // init db
    try initDb();
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
        content = get(snippet) catch hello;
    }
    const query = try req.query();
    const zigling = query.get("zigling") orelse "";
    if (!std.mem.eql(u8, zigling, "")) {
        const path = try std.fmt.allocPrint(req.arena, "./ziglings/exercises/{s}", .{zigling});
        var file = std.fs.cwd().openFile(path, .{}) catch {
            res.status = 404;
            res.body = "Not found";
            return;
        };
        content = try file.reader().readAllAlloc(req.arena, max_snippet_size);
        defer file.close();
    }

    var d = zmpl.Data.init(res.arena);
    defer d.deinit();
    var root = try d.root(.object);
    var c = try ziglyph.Collator.init(req.arena);
    defer c.deinit();

    //std.mem.sort(u8, ziglings_list.items, c, ziglyph.Collator.ascendingCaseless);
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

fn run(req: *httpz.Request, res: *httpz.Response) !void {
    var timer = try std.time.Timer.start();
    defer {
        const elapsed = timer.lap() / 1000;
        std.log.info("{any} {s} from {any} {d}ms", .{ req.method, req.url.raw, req.address, elapsed });
    }
    var f: output = undefined;
    const b = try req.formData();
    const code = b.get("body") orelse "";
    const isFmt = std.mem.containsAtLeast(u8, req.url.raw, 1, "fmt");
    f = try if (isFmt) runFmt(req.arena, code) else runCompile(req.arena, code);
    var err: []const u8 = "";
    if (!std.mem.eql(u8, f.stderr.?, "")) {
        err = f.stderr.?;
        var idx = std.mem.indexOfAny(u8, ".zig:", err).?;
        if (idx > 0) idx += 5;
        std.debug.print("{s}\n", .{err[idx .. err.len - 1]});
        err = err[idx .. err.len - 1];
    }

    if (isFmt) {
        try res.json(.{ .Error = err, .Body = f.stdout orelse "" }, .{});
    } else {
        try res.json(.{ .Errors = err, .Events = .{ .Message = f.stdout orelse "", .Kind = "stdout", .Delay = 0 }, .VetErrors = "" }, .{});
    }
}

fn share(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    _ = res;
}

fn metrics(req: *httpz.Request, res: *httpz.Response) !void {
    var timer = try std.time.Timer.start();
    defer {
        const elapsed = timer.lap() / 1000;
        std.log.info("{any} {s} from {any} {d}ms", .{ req.method, req.url.raw, req.address, elapsed });
    }
    res.content_type = .TEXT;
    return httpz.writeMetrics(res.writer());
}

const output = struct {
    stdout: ?[]const u8,
    stderr: ?[]const u8,
};

pub fn runFmt(alloc: std.mem.Allocator, code: []const u8) !output {
    const result = try zcmd.run(.{
        .allocator = alloc,
        .commands = &[_][]const []const u8{
            &.{ "zig", "fmt", "--stdin" },
        },
        .stdin_input = code,
    });
    return output{ .stdout = result.stdout, .stderr = result.stderr };
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
    return output{ .stdout = result.stdout, .stderr = result.stderr };
}

fn snippetId(body: []u8) ![]const u8 {
    // h := sha256.New()
    // 	io.WriteString(h, salt)
    // 	h.Write(s.Body)
    // 	sum := h.Sum(nil)
    // 	b := make([]byte, base64.URLEncoding.EncodedLen(len(sum)))
    // 	base64.URLEncoding.Encode(b, sum)
    // 	// Web sites don’t always linkify a trailing underscore, making it seem like
    // 	// the link is broken. If there is an underscore at the end of the substring,
    // 	// extend it until there is not.
    // 	hashLen := 11
    // 	for hashLen <= len(b) && b[hashLen-1] == '_' {
    // 		hashLen++
    // 	}
    // 	return string(b)[:hashLen]
    return body;
    // var out: [64]u8 = undefined;
    // var h = std.crypto.hash.sha2.Sha256.init(.{});
    // h.update(salt);
    // h.update(body);
    // h.final(out[0..]);
    // var b: []u8 =undefined;
    // std.base64.Base64Encoder.encode(encoder: *const Base64Encoder, dest: []u8, source: []const u8)

    // var hashLen = 11;
    // for (hashLen <= b.len and b[hashLen-1] == '_') {
    //     hashLen+=1;
    // }
    // return b[0..hashLen];
}

fn initDb() !void {
    const s3bucket = std.process.getEnvVarOwned(gpa, "AWS_BUCKET_NAME_S3") catch "play-zig";
    const s3endpoint = std.process.getEnvVarOwned(gpa, "AWS_ENDPOINT_URL_S3") catch "";
    db = try s3db.init(.{
        .mode = s3db.Db.Mode{ .Memory = {} },
        .open_flags = .{ .write = true },
    });
    defer db.deinit();
    if (!std.mem.eql(u8, s3endpoint, "")) {
        try db.exec("create virtual table if not exists snippets using s3db (s3_endpoint=$s3endpoint{[]const u8}, s3_bucket=$s3bucket{[]const u8}, s3_prefix='snippets', columns='key text primary key, value text')", .{}, .{ .s3endpoint = s3endpoint, .s3bucket = s3bucket });
    } else {
        try db.exec("create table if not exists snippets (key text primary key, value text)", .{}, .{});
    }
}
fn put(id: []const u8, code: []u8) !void {
    return try db.exec("insert into snippets(key, value) values($key{[]const u8}, $value{[]const u8})", .{}, .{ id, code });
}

fn get(id: []const u8) ![]const u8 {
    // var stmt = try db.prepare("select id from user where key = $key{[]const u8}");
    // defer stmt.deinit();

    // const id1 = try stmt.one([]u8, .{}, .{
    //     .key = id,
    // });

    // return id1.?;
    return id;
}
