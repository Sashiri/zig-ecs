const std = @import("std");
const ecs = @import("ecs");

// override the EntityTraits used by ecs
pub const EntityTraits = ecs.EntityTraitsType(.medium);

pub const Velocity = struct { x: f32, y: f32 };
pub const Position = struct { x: f32, y: f32 };

/// logs the timing for views vs non-owning groups vs owning groups with 1,000,000 entities
pub fn main() !void {
    var reg = ecs.Registry.init(std.heap.c_allocator);
    defer reg.deinit();

    // var timer = try std.time.Timer.start();

    createEntities(&reg);
    iterateView(&reg);
    nonOwningGroup(&reg);
    owningGroup(&reg);
}

fn createEntities(reg: *ecs.Registry) void {
    var timer = std.time.Timer.start() catch unreachable;
    var i: usize = 0;
    while (i < 1000000) : (i += 1) {
        var e1 = reg.create();
        reg.add(e1, Position{ .x = 1, .y = 1 });
        reg.add(e1, Velocity{ .x = 1, .y = 1 });
    }

    var end = timer.lap();
    std.debug.warn("create entities: \t{d}\n", .{@intToFloat(f64, end) / 1000000000});
}

fn iterateView(reg: *ecs.Registry) void {
    std.debug.warn("--- multi-view ---\n", .{});
    var view = reg.view(.{ Velocity, Position }, .{});

    var timer = std.time.Timer.start() catch unreachable;
    var iter = view.iterator();
    while (iter.next()) |entity| {
        var pos = view.get(Position, entity);
        const vel = view.getConst(Velocity, entity);

        pos.*.x += vel.x;
        pos.*.y += vel.y;
    }

    var end = timer.lap();
    std.debug.warn("view (iter): \t{d}\n", .{@intToFloat(f64, end) / 1000000000});
}

fn nonOwningGroup(reg: *ecs.Registry) void {
    std.debug.warn("--- non-owning ---\n", .{});
    var timer = std.time.Timer.start() catch unreachable;
    var group = reg.group(.{}, .{ Velocity, Position }, .{});
    var end = timer.lap();
    std.debug.warn("group (create): {d}\n", .{@intToFloat(f64, end) / 1000000000});

    timer.reset();
    var group_iter = group.iterator();
    while (group_iter.next()) |entity| {
        var pos = group.get(Position, entity);
        const vel = group.getConst(Velocity, entity);

        pos.*.x += vel.x;
        pos.*.y += vel.y;
    }

    end = timer.lap();
    std.debug.warn("group (iter): \t{d}\n", .{@intToFloat(f64, end) / 1000000000});
}

fn owningGroup(reg: *ecs.Registry) void {
    std.debug.warn("--- owning ---\n", .{});
    var timer = std.time.Timer.start() catch unreachable;
    var group = reg.group(.{ Velocity, Position }, .{}, .{});
    var end = timer.lap();
    std.debug.warn("group (create): {d}\n", .{@intToFloat(f64, end) / 1000000000});

    timer.reset();
    var group_iter = group.iterator(struct { vel: *Velocity, pos: *Position });
    while (group_iter.next()) |e| {
        e.pos.*.x += e.vel.x;
        e.pos.*.y += e.vel.y;
    }

    end = timer.lap();
    std.debug.warn("group (iter): \t{d}\n", .{@intToFloat(f64, end) / 1000000000});

    timer.reset();
    group.each(each);
    end = timer.lap();
    std.debug.warn("group (each): \t{d}\n", .{@intToFloat(f64, end) / 1000000000});

    timer.reset();

    // var storage = reg.assure(Velocity);
    // var vel = storage.instances.items;
    var pos = reg.assure(Position).instances.items;

    var index: usize = group.group_data.current;
    while (true) {
        if (index == 0) break;
        index -= 1;

        pos[index].x += pos[index].x;
        pos[index].y += pos[index].y;
    }

    end = timer.lap();
    std.debug.warn("group (direct): {d}\n", .{@intToFloat(f64, end) / 1000000000});
}

fn each(e: struct { vel: *Velocity, pos: *Position }) void {
    e.pos.*.x += e.vel.x;
    e.pos.*.y += e.vel.y;
}
