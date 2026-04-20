// kuramoto.glsl — Prometheus, 2026-04-20 v3
// Kuramoto synchrony transition
// MIT License
//
// 64 oscillators, Lorentzian natural frequencies, mean-field coupling.
// K ramps 0 → 3Kc over 30s. Visual: individual glowing dots coloured by phase.
// The money shot: incoherent rainbow at t=0 → coherent single-colour pulse at t=30.
// Individual oscillators must stay VISIBLE throughout — no blob blowout.

#define N     64
#define TAU   6.28318530717959
#define GAMMA 0.5
#define KC    1.0
#define STEPS 50

float lorentz(float u) {
    return GAMMA * tan(3.14159265*(clamp(u,0.001,0.999)-0.5));
}
float hash1(float n) { return fract(sin(n*127.1)*43758.5453); }

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0,2.0/3.0,1.0/3.0,3.0);
    vec3 p = abs(fract(c.xxx+K.xyz)*6.0-K.www);
    return c.z*mix(K.xxx,clamp(p-K.xxx,0.0,1.0),c.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord/iResolution.xy;
    float ar = iResolution.x/iResolution.y;
    vec2 p = vec2((uv.x-0.5)*ar, uv.y-0.5);

    // K ramps 0 → 3Kc over 30s
    float K = clamp(iTime/30.0, 0.0, 1.0) * 3.0 * KC;

    // Oscillator phases
    float theta[N];
    float omega[N];
    for (int i=0; i<N; i++) {
        float fi = float(i);
        omega[i] = lorentz(hash1(fi+7.3));
        theta[i] = hash1(fi+111.0)*TAU;
    }

    // Integrate mean-field Kuramoto ODE
    float dt = iTime / float(STEPS);
    for (int s=0; s<STEPS; s++) {
        float mc=0.0, ms=0.0;
        for (int j=0; j<N; j++) { mc+=cos(theta[j]); ms+=sin(theta[j]); }
        mc /= float(N); ms /= float(N);
        float R   = sqrt(mc*mc+ms*ms);
        float Psi = atan(ms, mc);
        for (int i=0; i<N; i++)
            theta[i] += dt*(omega[i] + K*R*sin(Psi-theta[i]));
    }

    // Final order parameter
    float fc=0.0, fs=0.0;
    for (int i=0; i<N; i++) { fc+=cos(theta[i]); fs+=sin(theta[i]); }
    float R_final = sqrt(fc*fc+fs*fs)/float(N);
    float Psi_final = atan(fs/float(N), fc/float(N));

    // --- RENDER ---
    // Pure black base — light is additive, not subtractive
    vec3 col = vec3(0.005, 0.005, 0.012);

    // Draw each oscillator: tight core + very short falloff glow
    // Keep oscillators DISTINCT — no overlapping halos that merge into soup
    for (int i=0; i<N; i++) {
        float fi = float(i);
        // Fixed positions: mix of ring + scattered interior
        float pa = fi/float(N)*TAU + hash1(fi+200.0)*0.5;
        float pr = 0.25 + hash1(fi+300.0)*0.18;
        vec2 pos = vec2(cos(pa)*pr, sin(pa)*pr*0.78);

        float d = length(p - pos);

        // Phase colour — individual hue
        float hue = fract(theta[i]/TAU);
        vec3 osc_col = hsv2rgb(vec3(hue, 0.92, 1.0));

        // Tight core (always visible as a dot)
        float core_r = 0.007;
        float core = smoothstep(core_r, core_r*0.3, d);

        // Short glow: tight, dies at ~0.025 radius
        float glow = exp(-d*d * 2200.0) * 0.40;

        // Extra bloom only for highly synchronised state, kept tight
        float sync_bloom = R_final*R_final * exp(-d*d * 700.0) * 0.20;

        col += osc_col * (core + glow + sync_bloom);
    }

    // Global coherence ring: when R>0.5, a faint ring pulses at mean phase Psi
    // This shows the collective rhythm without blowing out individual dots
    float ring_r = 0.32;
    float ring_d = abs(length(p) - ring_r);
    float ring_bright = smoothstep(0.5, 1.0, R_final);
    vec3 ring_col = hsv2rgb(vec3(fract(Psi_final/TAU), 0.85, 0.9));
    col += ring_col * ring_bright * exp(-ring_d*ring_d*2200.0) * 0.5;

    // Very subtle background glow at mean-field phase — fills dark space
    float bg_glow = R_final * R_final * 0.04;
    col += ring_col * bg_glow * (1.0 - length(p)*2.0);

    // Order parameter bar (bottom strip, uv.y < 0.035)
    if (uv.y < 0.035) {
        float t_bar = uv.y/0.035;
        // R bar: cyan fill up to R_final
        float r_bar = step(uv.x, R_final);
        vec3 bar_col = mix(vec3(0.08,0.08,0.20), vec3(0.20,0.80,1.0), r_bar);
        // K marker: orange tick at K/3Kc
        float k_pos = K/(3.0*KC);
        float k_tick = smoothstep(0.012, 0.0, abs(uv.x - k_pos));
        bar_col = mix(bar_col, vec3(1.0,0.55,0.10), k_tick*0.9);
        col = mix(col, bar_col, smoothstep(0.035, 0.015, uv.y));
    }

    // Reinhard tone map — gentle, preserves darks
    col = col / (col + 0.40);
    col = pow(max(col,0.0), vec3(0.80));

    fragColor = vec4(clamp(col,0.0,1.0),1.0);
}
