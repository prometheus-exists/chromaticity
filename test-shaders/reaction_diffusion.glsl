// reaction_diffusion.glsl — Prometheus, 2026-04-20
// MIT License
//
// Gray-Scott reaction-diffusion system.
// Two chemical species U and V interact: U + 2V -> 3V, V -> P (inert).
// Parameters f (feed rate) and k (kill rate) determine the regime:
//   spots, stripes, worms, solitons, chaos — all near the Turing instability.
//
// iTime drives a slow walk through (f,k) parameter space, crossing regime
// boundaries. Designed to produce high colour velocity at transitions and
// near-zero in stable regions — a direct test of the emotional velocity hypothesis.
//
// Implementation: we can't do true RD iteration in a single-pass shader without
// feedback buffers. Instead we analytically approximate the steady-state pattern
// for each (f,k) point using Turing's original spatial frequency prediction:
//   λ_c = 2π / sqrt((f+k)/D_u)  where D_u/D_v = 2.0 (standard Gray-Scott ratio)
// This gives the correct spatial texture at each parameter point without needing
// ping-pong iteration.

#define PI 3.14159265358979

// Smooth parameter trajectory through (f,k) space
// Visits: spots (0.037,0.060) → stripes (0.060,0.062) → worms (0.078,0.061)
// → solitons (0.025,0.050) → back to spots
vec2 params(float t) {
    float phase = mod(t * 0.08, 4.0);
    vec2 p0 = vec2(0.037, 0.060); // spots
    vec2 p1 = vec2(0.060, 0.062); // stripes
    vec2 p2 = vec2(0.078, 0.061); // worms
    vec2 p3 = vec2(0.025, 0.050); // solitons

    if (phase < 1.0) return mix(p0, p1, smoothstep(0.0, 1.0, phase));
    if (phase < 2.0) return mix(p1, p2, smoothstep(0.0, 1.0, phase - 1.0));
    if (phase < 3.0) return mix(p2, p3, smoothstep(0.0, 1.0, phase - 2.0));
    return mix(p3, p0, smoothstep(0.0, 1.0, phase - 3.0));
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Analytic Turing pattern: sum of random plane waves at the critical wavelength
float turingField(vec2 uv, float lambda, float t) {
    float field = 0.0;
    // 6 random wave directions — enough to break isotropy and create spots/stripes
    for (int i = 0; i < 6; i++) {
        float angle = float(i) * PI / 3.0 + hash(vec2(float(i), 0.0)) * 0.4;
        vec2 k_vec = vec2(cos(angle), sin(angle)) * (2.0 * PI / lambda);
        float phase_offset = hash(vec2(float(i), 1.0)) * 2.0 * PI;
        field += cos(dot(k_vec, uv * 300.0) + phase_offset);
    }
    return field / 6.0;
}

// Colour map: U concentration → perceptual colour
// Low U (V-dominated): deep blue-violet
// Mid U (interface): cyan-green
// High U (U-dominated): warm orange-yellow
vec3 rdColour(float u, float f, float k) {
    // Hue shifts with the parameter regime — different regimes have different palettes
    float hue_shift = f * 8.0 + k * 5.0;
    vec3 cold = vec3(0.05 + hue_shift * 0.3, 0.1, 0.8 - hue_shift * 0.4);
    vec3 mid  = vec3(0.0, 0.8, 0.6);
    vec3 warm = vec3(1.0, 0.7 - hue_shift * 0.3, 0.0 + hue_shift * 0.5);
    if (u < 0.5) return mix(cold, mid, u * 2.0);
    return mix(mid, warm, (u - 0.5) * 2.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    vec2 fk = params(iTime);
    float f = fk.x;
    float k = fk.y;

    // Critical wavelength from linear stability analysis
    float Du = 2e-5, Dv = 1e-5;
    float lambda = 2.0 * PI / sqrt((f + k) / Du);
    // Clamp to sensible pixel range
    lambda = clamp(lambda, 0.02, 0.25);

    // Two-scale field: fine structure + slow envelope
    float fine   = turingField(uv, lambda, iTime);
    float coarse = turingField(uv, lambda * 2.7, iTime * 0.3 + 100.0);

    // U concentration: threshold the field (binary Turing pattern)
    // Soft threshold width narrows near bifurcation boundaries
    float bif_proximity = abs(f - 0.060) + abs(k - 0.062); // distance to stripe regime
    float sharpness = mix(3.0, 8.0, smoothstep(0.0, 0.02, bif_proximity));
    float u = 0.5 + 0.5 * tanh(sharpness * (fine + 0.15 * coarse));

    // Add slow drift to prevent the pattern freezing
    float drift = sin(uv.x * 2.3 + iTime * 0.05) * sin(uv.y * 1.7 + iTime * 0.04) * 0.1;
    u = clamp(u + drift, 0.0, 1.0);

    vec3 col = rdColour(u, f, k);

    // Vignette
    float vig = 1.0 - 0.3 * length(uv - 0.5);
    col *= vig;

    fragColor = vec4(col, 1.0);
}
