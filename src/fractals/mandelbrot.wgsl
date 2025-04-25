// https://github.com/BenjaminAster/WebGPU-Mandelbrot/blob/main/shader.wgsl
struct VertexOutput {
	@builtin(position) position: vec4<f32>,
	@location(0) fragmentPosition: vec2<f32>,
}

struct Params {
    // lo_real: f32,
    // lo_imag: f32,
    // hi_real: f32,
    // hi_imag: f32,
    center_real: f32,
    center_imag: f32,
    radius_real: f32,
    radius_imag: f32,
    width: u32,
    height: u32,
    z0_real: f32,
    z0_imag: f32,
    max_depth: u32,
    cycle_depth: u32, // this is a ~sentinel for if it finds a cycle
}

@group(0) @binding(0) var<uniform> params: Params;


fn get_depth(c_real: f32, c_imag: f32) -> vec2<f32> {
    var z_real = params.z0_real;
    var z_imag = params.z0_imag;
    var old_real = z_real;
    var old_imag = z_imag;
    var z_real2 = z_real * z_real;
    var z_imag2 = z_imag * z_imag;
    var period_i = 0;
    var period_len = 1;
    for (var depth: u32 = 0; depth < params.max_depth; depth++) {
        let mag2 = z_real2 + z_imag2;
        if mag2 > 1000.0 {
            return vec2(f32(depth) - log(log(mag2))/log(2.0), 1.0);
        }
        z_imag = (z_real + z_real) * z_imag + c_imag;
        z_real = z_real2 - z_imag2 + c_real;
        z_real2 = z_real * z_real;
        z_imag2 = z_imag * z_imag;

        if ((old_real == z_real) && (old_imag == z_imag)) {
            // TODO: remove
            return vec2(f32(depth), 0.0);
            // return f32(params.cycle_depth);
        }

        period_i += 1;
        if (period_i > period_len) {
            period_i = 0;
            period_len += 1;
            old_real = z_real;
            old_imag = z_imag;
        }
    }
    return vec2(f32(params.max_depth), 1.0);
}

@vertex
fn vertex_main(@builtin(vertex_index) vertexIndex: u32) -> VertexOutput {
    // this is so that i don't need to pass in a vertex buffer
	// var positions: array<vec2<f32>, 4> = array<vec2<f32>, 4>(
	// 	vec2<f32>(1.0, -1.0),
	// 	vec2<f32>(1.0, 1.0),
	// 	vec2<f32>(-1.0, -1.0),
	// 	vec2<f32>(-1.0, 1.0),
	// );
	var positions: array<vec2<f32>, 6> = array<vec2<f32>, 6>(
		vec2<f32>(1.0, -1.0),
		vec2<f32>(1.0, 1.0),
		vec2<f32>(-1.0, 1.0),
		vec2<f32>(-1.0, 1.0),
		vec2<f32>(-1.0, -1.0),
		vec2<f32>(1.0, -1.0),
	);
	let position2d: vec2<f32> = positions[vertexIndex];
	return VertexOutput(vec4<f32>(position2d, 0.0, 1.0), position2d);
}

fn get_next_power_of_2(x: u32) -> u32 {
    var i: u32 = 1;
    while (i < x) {
        i = i << 1;
    }
    return i;
}

@fragment
fn fragment_main(input: VertexOutput) -> @location(0) vec4<f32> {
    var out = get_depth(
        params.center_real + input.fragmentPosition.x * params.radius_real,
        params.center_imag + input.fragmentPosition.y * params.radius_imag
    );
    var depth = out.x;
    var color: f32;
    if depth == f32(params.max_depth) {
        color = 0.0;
    } else if depth == f32(params.cycle_depth) {
        color = 0.0;
    } else {
        depth -= 1.5;
        var out_color = rainbow(fract(select(depth, log(depth + 1.0), depth > 0.0)));
        if out.y == 0.0 {
            out_color.a = 0.02;
        }
        return out_color;
    }
    return vec4<f32>(color, color, color, 1.0);
}

fn rainbow(t: f32) -> vec4<f32> {
    let ts = abs(t - 0.5);
    let h = 360.0 * t - 100.0;
    let s = 1.5 - 1.5 * ts;
    let l = 0.8 - 0.9 * ts;
    return cubehelix(vec3(h, s, l));
}

fn cubehelix(c: vec3<f32>) -> vec4<f32> {
    const DEG2RAD: f32 = 3.1415926535897932384626433 / 180.0;
    let h = (c.x + 120.0) * DEG2RAD;
    let l = c.z;
    let a = c.y * l * (1.0 - l);
    let cosh = cos(h);
    let sinh = sin(h);
    let r = min(1.0, (l - a * (0.14861 * cosh - 1.78277 * sinh)));
    let g = min(1.0, (l - a * (0.29227 * cosh + 0.90649 * sinh)));
    let b = min(1.0, (l + a * (1.97294 * cosh)));
    return vec4(r, g, b, 1.0);
}
