// standing_wave.glsl — Prometheus, 2026-04-20
// MIT License
//
// Two counter-propagating waves with slightly different frequencies (beat frequency).
// The interference produces a slow-pulsing envelope (emotional layer) modulating
// a fast spatial carrier (motion layer).
//
// Design intent: decouple luminance rhythm from colour rhythm.
//   - Carrier frequency: ~8 Hz spatial oscillation
//   - Beat envelope: ~0.2 Hz (5s period) — the "breath" of the pattern
//   - Colour rotates with the *phase* of the envelope, not the carrier
//
// This means luminance pulses at beat frequency while colour cycles independently.
// If our probe's luminance and colour scores are truly independent, this shader
// should show: high motion score, periodic luminance, and a colour score that
// doesn't track the luminance rhythm.
//
// Also: the two waves travel in directions 30° offset from horizontal, producing
// a hexagonal interference lattice — a nod to Turing's prediction that 2D Turing
// patterns naturally tile in hexagonal symmetry.

#define PI 3.14159265358979
#define TAU 6.28318530717959

// Convert HSV to RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - iResolution.xy * 0.5) / min(iResolution.x, iResolution.y);

    // Carrier: spatial frequency in px^-1 (normalised)
    float k_carrier = 12.0;
    // Beat: difference frequency between the two counter-propagating waves
    float f_beat = 0.18; // Hz — ~5.5s envelope period
    float f_carrier = 1.8; // Hz — fast oscillation

    // Three wave directions at 0°, 60°, 120° — hexagonal lattice
    vec3 wave = vec3(0.0);
    for (int i = 0; i < 3; i++) {
        float angle = float(i) * PI / 3.0;
        vec2 dir = vec2(cos(angle), sin(angle));

        // Forward wave
        float phi_fwd = k_carrier * dot(dir, uv) - TAU * f_carrier * iTime;
        // Backward wave (slightly different frequency → beat)
        float phi_bwd = k_carrier * dot(-dir, uv) - TAU * (f_carrier - f_beat) * iTime;

        wave[i] = cos(phi_fwd) + cos(phi_bwd);
    }

    // Combine: product gives hexagonal standing wave with beat envelope
    float interference = (wave.x + wave.y + wave.z) / 3.0;

    // Slow envelope — beat frequency, spatial average
    float envelope = 0.5 + 0.5 * sin(TAU * f_beat * iTime);

    // Luminance: tracks interference amplitude modulated by envelope
    float lum = 0.5 + 0.4 * interference * envelope;

    // Colour: rotates with envelope *phase*, not carrier phase
    // Hue completes one rotation per 2 beat periods — slower than luminance
    float hue = mod(iTime * f_beat * 0.5 + 0.3 * interference, 1.0);
    float sat = 0.7 + 0.3 * abs(interference);
    float val = clamp(lum, 0.1, 1.0);

    vec3 col = hsv2rgb(vec3(hue, sat, val));

    // Edge softening — interference rings at boundary
    float r = length(uv);
    float edge = smoothstep(0.55, 0.45, r);
    col *= edge;
    col += (1.0 - edge) * vec3(0.02, 0.02, 0.05);

    fragColor = vec4(col, 1.0);
}
