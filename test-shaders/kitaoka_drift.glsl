// kitaoka_drift.glsl — Prometheus, 2026-04-20
// MIT License
//
// Based on Akiyoshi Kitaoka's "Rotating Snakes" peripheral drift illusion
// (Kitaoka & Ashida, 2003; Kitaoka, Ritsumeikan University).
// The original static image creates a strong perception of rotation/drift
// in peripheral vision. This shader animates the luminance phase parameter
// to make the underlying mechanism explicit and measurable.
//
// Mechanism (Fraser-Wilcox / Kitaoka model):
//   The sawtooth luminance gradient (black→dark grey→white→light grey) within
//   each concentric stripe exploits asymmetric ON/OFF ganglion cell responses.
//   The visual system infers motion toward the steep (black→dark) transition.
//   This is a low-level retinal effect, not cognitive — it survives fixation
//   breaks and occurs before conscious processing.
//
// iTime role: slowly rotates the phase of the luminance gradient around each
// annular ring. This makes the "illusory" motion into real pixel motion,
// allowing the probe to compare pixel-level SSIM against what a human would
// perceive from the static version.
//
// Probe hypothesis: at iTime=0 (static), a human sees strong motion.
//   The probe sees ~zero SSIM dissimilarity. As iTime increases, the probe's
//   SSIM score rises to match the perceptual report. The gap between static
//   perceptual motion and zero SSIM at t=0 is the measurement the static
//   version of this illusion would expose.

#define PI 3.14159265358979
#define TAU 6.28318530717959
#define N_RINGS 7

// Kitaoka luminance sequence: 4 zones per stripe period
// Values calibrated to Fraser-Wilcox (1979) and Kitaoka (2003) specifications
float kitaokaLuminance(float phase) {
    float p = fract(phase / TAU);
    // Four-zone sawtooth: black → dark_grey → white → light_grey
    if (p < 0.25) return mix(0.03, 0.15, p * 4.0);          // black → dark grey (steep = perceived motion direction)
    if (p < 0.50) return mix(0.15, 0.97, (p - 0.25) * 4.0); // dark grey → white
    if (p < 0.75) return mix(0.97, 0.72, (p - 0.50) * 4.0); // white → light grey
    return mix(0.72, 0.03, (p - 0.75) * 4.0);               // light grey → black (reset)
}

// Colour of each ring — alternating warm/cool to match Kitaoka's colour variant
vec3 ringColour(int ring, float lum) {
    // Odd rings: warm (red-orange hue); even rings: cool (blue-green hue)
    // Saturation inversely proportional to luminance — shadows are more saturated
    float sat = 0.6 * (1.0 - lum * 0.5);
    vec3 warm = mix(vec3(lum), vec3(lum * 1.3, lum * 0.7, lum * 0.4), sat);
    vec3 cool = mix(vec3(lum), vec3(lum * 0.4, lum * 0.8, lum * 1.4), sat);
    return (ring % 2 == 0) ? warm : cool;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - iResolution.xy * 0.5) / min(iResolution.x, iResolution.y);

    float r = length(uv);
    float theta = atan(uv.y, uv.x);

    // Which ring are we in?
    float ring_width = 0.065;
    float ring_f = r / ring_width;
    int ring = int(ring_f);

    if (ring >= N_RINGS || r < 0.02) {
        fragColor = vec4(vec3(0.5), 1.0); // background grey
        return;
    }

    // Position within ring (0=inner edge, 1=outer edge)
    float ring_pos = fract(ring_f);

    // Angular stripe frequency — number of stripe cycles per revolution
    // Increases with ring number to maintain roughly constant stripe width in pixels
    float stripes_per_rev = 12.0 + float(ring) * 2.0;

    // Phase: angular position * stripe frequency + slow iTime rotation
    // Alternating rings rotate in opposite directions (classic Rotating Snakes)
    float direction = (ring % 2 == 0) ? 1.0 : -1.0;
    float stripe_phase = theta * stripes_per_rev + direction * iTime * 0.4;

    // Radial gradient blends between inner and outer stripe phase
    // (gives the ring its curved appearance)
    float radial_warp = sin(ring_pos * PI) * 0.8;
    stripe_phase += radial_warp;

    float lum = kitaokaLuminance(stripe_phase);

    // Soft ring edge antialiasing
    float edge_inner = smoothstep(0.0, 0.08, ring_pos);
    float edge_outer = smoothstep(1.0, 0.92, ring_pos);
    float edge = edge_inner * edge_outer;

    vec3 col = ringColour(ring, lum);

    // Blend with background grey at ring edges
    col = mix(vec3(0.5), col, edge);

    // Outer background fade
    float outer_fade = smoothstep(float(N_RINGS) * ring_width + 0.02,
                                   float(N_RINGS) * ring_width - 0.04, r);
    col = mix(vec3(0.5), col, outer_fade);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
