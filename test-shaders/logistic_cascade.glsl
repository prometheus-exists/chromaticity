// logistic_cascade.glsl — Prometheus, 2026-04-20
// MIT License
//
// The logistic map: x_{n+1} = r * x_n * (1 - x_n)
// For r < 3.0: stable fixed point. Period-doubles at r=3, 3.45, 3.54, 3.57...
// Beyond r≈3.57: chaos. The Feigenbaum cascade.
//
// Each column of pixels (x-axis) corresponds to a different r value [2.5, 4.0].
// The y-axis shows attractor density — brighter where the orbit spends more time.
// iTime drives a slow zoom into the Feigenbaum point (r≈3.5699...) from the left,
// revealing progressively finer bifurcation structure.
//
// Metrics prediction:
//   - Luminance: slowly increasing as more of the bifurcation structure is revealed
//   - Colour: dramatic shifts at bifurcation points (period-2, period-4, chaos onset)
//   - Motion: high near bifurcation points, near-zero in stable regions
//
// This shader was designed to stress-test whether our probe detects regime changes.

#define FEIGENBAUM 3.56994567
#define ITER 200
#define WARMUP 100

// Colour map: period → colour
// Stable (period 1): deep blue
// Period 2: teal
// Period 4: green
// Period 8: yellow-green
// Chaos: red-orange
// Intermittency windows (r>3.57 stable islands): white hotspot
vec3 orbitColour(float r, float density) {
    // Coarse period estimate from r
    float t = smoothstep(2.9, 3.0, r);      // period 1 → 2
    float t2 = smoothstep(3.44, 3.46, r);   // period 2 → 4
    float t3 = smoothstep(3.54, 3.56, r);   // period 4 → 8
    float t4 = smoothstep(3.569, 3.575, r); // 8 → chaos onset

    vec3 c_stable  = vec3(0.05, 0.10, 0.70);
    vec3 c_period2 = vec3(0.05, 0.60, 0.70);
    vec3 c_period4 = vec3(0.10, 0.80, 0.30);
    vec3 c_period8 = vec3(0.70, 0.90, 0.10);
    vec3 c_chaos   = vec3(0.90, 0.30, 0.05);

    vec3 col = c_stable;
    col = mix(col, c_period2, t);
    col = mix(col, c_period4, t2);
    col = mix(col, c_period8, t3);
    col = mix(col, c_chaos,   t4);

    // Brighten by density — common orbit values are brighter
    col *= (0.2 + 0.8 * density);

    // Intermittency windows in chaos: bright white hotspots
    float window1 = exp(-pow((r - 3.6278) / 0.003, 2.0)); // period-3 window
    col = mix(col, vec3(1.0), window1 * 0.8);

    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // iTime drives a zoom: start showing [2.5, 4.0], slowly zoom toward chaos onset
    float zoom_t = smoothstep(0.0, 40.0, iTime);
    float r_min = mix(2.5, 3.40, zoom_t);
    float r_max = mix(4.0, 3.75, zoom_t * 0.7);

    float r = mix(r_min, r_max, uv.x);
    float y_screen = uv.y;

    // Iterate the logistic map, count how many iterations land near y_screen
    float x = 0.5 + sin(iTime * 0.01) * 0.1; // slow drift of initial condition
    float density = 0.0;
    float bin_width = 1.5 / iResolution.y;

    for (int i = 0; i < ITER + WARMUP; i++) {
        x = r * x * (1.0 - x);
        if (i >= WARMUP) {
            float dist = abs(x - y_screen);
            density += exp(-dist * dist / (bin_width * bin_width));
        }
    }
    density /= float(ITER);
    density = clamp(density * 8.0, 0.0, 1.0);

    vec3 col = orbitColour(r, density);

    // Vertical guide lines at key bifurcation values
    float guide = 0.0;
    float r_norm = (r - r_min) / (r_max - r_min);
    // These are the first few bifurcation r values
    float[5] bifurcations = float[5](3.0, 3.449, 3.544, 3.5644, 3.5688);
    for (int b = 0; b < 5; b++) {
        float r_b_norm = (bifurcations[b] - r_min) / (r_max - r_min);
        guide += 0.15 * exp(-pow((uv.x - r_b_norm) * iResolution.x / 2.0, 2.0));
    }
    col += vec3(guide * 0.4, guide * 0.3, guide * 0.6);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
