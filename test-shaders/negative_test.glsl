// negative_test.glsl — Static Mandelbrot (near-zero iTime sensitivity)
// Purpose: calibration negative case for render-probe sensitivity thresholds.
// iTime is NOT used. Visual output is completely static.
// Expected probe result: iTime sensitivity ≈ 0.0, SSIM dissimilarity ≈ 0.0
//
// A probe that returns non-zero sensitivity on this shader has a measurement artefact
// (e.g. numerical noise, framebuffer clearing, GPU rounding variance between frames).
// That artefact defines the noise floor for all other sensitivity measurements.

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Map pixel to complex plane centred on an interesting region
    vec2 c = (fragCoord / iResolution.xy - vec2(0.5, 0.5)) * vec2(3.5, 2.5) - vec2(0.7, 0.0);
    vec2 z = vec2(0.0);
    float iter = 0.0;
    for (float n = 0.0; n < 128.0; n++) {
        if (dot(z, z) > 4.0) break;
        z = vec2(z.x*z.x - z.y*z.y + c.x, 2.0*z.x*z.y + c.y);
        iter = n;
    }
    // Smooth colouring
    float t = iter / 128.0;
    vec3 col = 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
    fragColor = vec4(col, 1.0);
}
