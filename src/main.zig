const std = @import("std");
const rl = @import("raylib");

const WIDTH = 800;
const HEIGHT = 800;
const GRAVITY = 0.5;
const PARTICLE_SIZE = 5;
const MAX_PARTICLES = WIDTH * HEIGHT;
const MAX_SPEED = 10;
const GRID_WIDTH = WIDTH / PARTICLE_SIZE;
const GRID_HEIGHT = HEIGHT / PARTICLE_SIZE;

const Particle = struct {
    kind: Kind,
    updated: bool,
    speed: f32,
    life_time: f64,
};

const Kind = enum {
    Air,
    Ground,
    Sand,
};

pub fn main() !void {
    rl.setTraceLogLevel(.log_info);
    rl.initWindow(WIDTH, HEIGHT, "Sand");
    defer rl.closeWindow();

    var particles: [GRID_WIDTH][GRID_HEIGHT]Particle = undefined;
    for (particles, 0..) |_, i| {
        for (particles[i], 0..) |_, j| {
            particles[i][j] = Particle{
                .kind = .Air,
                .life_time = rl.getTime(),
                .speed = 0,
                .updated = false,
            };
        }
    }

    rl.setTargetFPS(60);
    var delta = rl.getTime();
    while (!rl.windowShouldClose()) {
        resetUpdatedParticles(&particles);
        try updateParticles(&particles, &delta);

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        for (particles, 0..) |_, i| {
            for (particles[i], 0..) |particle, j| {
                switch (particle.kind) {
                    .Sand => {
                        rl.drawRectangle(
                            @intCast(i * PARTICLE_SIZE),
                            @intCast(j * PARTICLE_SIZE),
                            PARTICLE_SIZE,
                            PARTICLE_SIZE,
                            rl.Color{ .r = 203, .g = 189, .b = 147, .a = 255 },
                        );
                    },
                    else => {
                        rl.drawRectangle(
                            @intCast(i * PARTICLE_SIZE),
                            @intCast(j * PARTICLE_SIZE),
                            PARTICLE_SIZE,
                            PARTICLE_SIZE,
                            rl.Color.dark_gray,
                        );
                    },
                }
            }
        }
        rl.drawFPS(10, 10);
    }
}

fn updateParticles(particles: *[GRID_WIDTH][GRID_HEIGHT]Particle, delta: *f64) !void {
    // Spawn new sand particles with random spread
    if (rl.isMouseButtonDown(.mouse_button_left)) {
        const mouseX = rl.getMouseX();
        const mouseY = rl.getMouseY();

        // Spawn multiple particles per click/frame
        var i: usize = 0;
        const particles_per_click = 3;
        const spread_radius = 10;

        while (i < particles_per_click) : (i += 1) {
            // Generate random offset from mouse position
            const offsetX = rl.getRandomValue(-spread_radius, spread_radius);
            const offsetY = rl.getRandomValue(-spread_radius, spread_radius);

            // Calculate final position with offset
            const finalX = mouseX + offsetX;
            const finalY = mouseY + offsetY;

            // Convert to grid coordinates
            const x: usize = @intCast(if (@divFloor(finalX, PARTICLE_SIZE) < 0)
                0
            else
                @divFloor(finalX, PARTICLE_SIZE));
            const y: usize = @intCast(if (@divFloor(finalY, PARTICLE_SIZE) < 0)
                0
            else
                @divFloor(finalY, PARTICLE_SIZE));

            // Check bounds
            if (x >= GRID_WIDTH or y >= GRID_HEIGHT) {
                continue;
            }

            // Only spawn if the cell is empty
            if (particles[x][y].kind == .Air) {
                particles[x][y] = Particle{
                    .kind = .Sand,
                    .speed = 0.5,
                    .life_time = rl.getTime(),
                    .updated = false,
                };
            }
        }
        delta.* = rl.getTime();
    }

    // Update existing particles from bottom to top
    var row: usize = GRID_HEIGHT;
    while (row > 0) : (row -= 1) {
        const y = row - 1;
        var x: usize = 0;
        while (x < GRID_WIDTH) : (x += 1) {
            if (!particles[x][y].updated and particles[x][y].kind == .Sand) {
                // Compute new particle speed because of G
                particles[x][y].speed += @floatCast(GRAVITY * (rl.getTime() - particles[x][y].life_time));
                if (particles[x][y].speed > MAX_SPEED) {
                    particles[x][y].speed = MAX_SPEED;
                }
                const steps: usize = @intFromFloat(@round(particles[x][y].speed));

                var current_y = y;
                for (0..steps) |step| {
                    current_y += step;

                    // Check if we can move down
                    if (current_y < GRID_HEIGHT - 1 and particles[x][current_y + 1].kind == .Air) {
                        // Move down
                        particles[x][current_y + 1] = particles[x][current_y];
                        particles[x][current_y + 1].updated = true;
                        particles[x][current_y] = Particle{
                            .kind = .Air,
                            .speed = 0,
                            .life_time = rl.getTime(),
                            .updated = false,
                        };
                    } else if (current_y < GRID_HEIGHT - 1) {
                        // Try to move diagonally
                        if (x > 0 and particles[x - 1][current_y + 1].kind == .Air) {
                            // Move down-left
                            particles[x - 1][current_y + 1] = particles[x][current_y];
                            particles[x - 1][current_y + 1].updated = true;
                            particles[x][current_y] = Particle{
                                .kind = .Air,
                                .speed = 0,
                                .life_time = rl.getTime(),
                                .updated = false,
                            };
                        } else if (x < GRID_WIDTH - 1 and particles[x + 1][current_y + 1].kind == .Air) {
                            // Move down-right
                            particles[x + 1][current_y + 1] = particles[x][current_y];
                            particles[x + 1][current_y + 1].updated = true;
                            particles[x][current_y] = Particle{
                                .kind = .Air,
                                .speed = 0,
                                .life_time = rl.getTime(),
                                .updated = false,
                            };
                        } else {
                            particles[x][y].speed = 0;
                            particles[x][y].life_time = rl.getTime();
                            break;
                        }
                    } else {
                        particles[x][y].speed = 0;
                        particles[x][y].life_time = rl.getTime();
                        break;
                    }
                }
            }
        }
    }
}

fn resetUpdatedParticles(particles: *[GRID_WIDTH][GRID_HEIGHT]Particle) void {
    for (particles, 0..) |_, i| {
        for (particles[i], 0..) |_, j| {
            particles[i][j].updated = false;
        }
    }
}
