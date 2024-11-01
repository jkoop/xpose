const std = @import("std");

pub fn main() !void {
    if (std.os.argv.len < 4) {
        std.debug.print(
            \\Usage: {s} <output> <width> <height> [smoothing] [percentile]
            \\
            \\Example: ffmpeg -framerate 10 -f x11grab -i :0.0 -filter:v scale=100:100 -f rawvideo -c:v rawvideo -pix_fmt rgb24 -y /dev/stdout 2&>0 | {s} HDMI-0 100 100 | bash
            \\
        , .{ std.os.argv[0], std.os.argv[0] });
        return;
    }

    const output = std.os.argv[1];
    const width = std.fmt.parseInt(u32, std.mem.span(std.os.argv[2]), 10) catch {
        std.debug.panic("Invalid width: {s}", .{std.os.argv[2]});
    };
    const height = std.fmt.parseInt(u32, std.mem.span(std.os.argv[3]), 10) catch {
        std.debug.panic("Invalid height: {s}", .{std.os.argv[3]});
    };
    const smoothing: f32 = if (std.os.argv.len > 4) std.fmt.parseFloat(f32, std.mem.span(std.os.argv[4])) catch 0.9 else 0.9;
    const percentile: u8 = if (std.os.argv.len > 5) std.fmt.parseInt(u8, std.mem.span(std.os.argv[5]), 10) catch 90 else 90;

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator();
    defer _ = gpa.deinit();

    const buffer_rgb: []u8 = try allocator.alloc(u8, width * height * 3);
    defer allocator.free(buffer_rgb);

    const buffer_grey: []u8 = try allocator.alloc(u8, width * height);
    defer allocator.free(buffer_grey);

    var brightness: f32 = 1.0;
    var bytes_read: usize = 0;

    while (true) {
        bytes_read = stdin.readAtLeast(buffer_rgb, buffer_rgb.len) catch |err| {
            std.debug.print("Error reading input: {}\n", .{err});
            return;
        };
        // std.debug.print("Read {d} bytes\n", .{bytes_read});
        if (bytes_read == 0) {
            std.debug.print("Read 0 bytes, exiting.\n", .{});
            break;
        }

        // convert rgb to grey
        for (buffer_grey, 0..) |_, i| {
            buffer_grey[i] = @max(buffer_rgb[i * 3 + 0], buffer_rgb[i * 3 + 1], buffer_rgb[i * 3 + 2]);
        }

        // sort buffer_grey ascending
        std.sort.heap(u8, buffer_grey, {}, comptime std.sort.asc(u8));

        // consider the percentile'th percentile
        const ninetieth_pixel: f32 = @as(f32, @floatFromInt(buffer_grey[buffer_grey.len * percentile / 100])) / 255.0;
        const new_brightness = 1.0 / ninetieth_pixel;
        brightness = brightness * smoothing + new_brightness * (1.0 - smoothing);
        if (brightness > 100.0) {
            brightness = 100.0;
        }
        stdout.print("xrandr --output {s} --brightness {d}\n", .{ output, brightness }) catch |err| {
            std.debug.print("Error printing output: {}\n", .{err});
            return;
        };
        std.debug.print("Brightness: {d}\n", .{brightness});
    }
}
