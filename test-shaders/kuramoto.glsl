// kuramoto.glsl — Prometheus, 2026-04-20 v1
// Kuramoto synchrony transition
// MIT License
//
// N oscillators on a 2D plane, each with a natural frequency ω_i drawn
// from a Lorentzian distribution (half-width γ = 0.5).
// Coupled via the Kuramoto ODE:
//   dθ_i/dt = ω_i + (K/N) Σ_j sin(θ_j - θ_i)
//
// iTime drives K: 0 → 3·K_c over 30s.
// Critical coupling: K_c = 2γ/π·g(0) = 2γ = 1.0 (for γ=0.5, g(0)=1/πγ)
//
// Visual: each oscillator = glowing disc, colour = phase θ (HSL hue).
// Below K_c: independent kaleidoscope. At K_c: coherence begins.
// Above K_c: synchronised pulse — all colours align, whole field breathes.
//
// Order parameter R = |mean(e^{iθ})| modulates global bloom intensity.

#define N     64       // number of oscillators
#define TAU   6.28318530717959
#define GAMMA 0.5      // Lorentzian half-width
#define KC    1.0      // K_c = 2*GAMMA
#define STEPS 40       // Euler integration steps per frame

// Lorentzian-distributed frequencies via quantile function
// F^{-1}(u) = GAMMA * tan(PI*(u - 0.5))
float lorentzian_freq(float u) {
    return GAMMA * tan(3.14159265 * (clamp(u, 0.001, 0.999) - 0.5));
}

float hash1(float n) { return fract(sin(n*127.1)*43758.5453); }
vec2  hash2(float n) { return vec2(hash1(n), hash1(n+73.1)); }

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0,2.0/3.0,1.0/3.0,3.0);
    vec3 p = abs(fract(c.xxx+K.xyz)*6.0-K.www);
    return c.z*mix(K.xxx,clamp(p-K.xxx,0.0,1.0),c.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float ar = iResolution.x / iResolution.y;
    vec2 p = vec2((uv.x-0.5)*ar, uv.y-0.5); // centred

    // Coupling K ramps from 0 to 3*Kc over 30 seconds
    float K = clamp(iTime / 30.0, 0.0, 1.0) * 3.0 * KC;

    // Build oscillator state:
    // ω_i = Lorentzian frequency
    // θ_i(t) = integrated via Euler from θ_i(0) = 2π·hash
    // We integrate forward STEPS times per fragment (expensive but N=64 is fine)
    float theta[N];
    float omega[N];

    // Initialise phases and frequencies
    for (int i = 0; i < N; i++) {
        float fi = float(i);
        omega[i] = lorentzian_freq(hash1(fi + 7.3));
        theta[i] = hash1(fi + 111.0) * TAU; // initial phase
    }

    // Integrate ODE with Euler steps
    // dt chosen so STEPS*dt = iTime
    float dt = iTime / float(STEPS);
    for (int s = 0; s < STEPS; s++) {
        // Compute mean field: R·e^{iΨ} = (1/N) Σ e^{iθ_j}
        float mean_cos = 0.0, mean_sin = 0.0;
        for (int j = 0; j < N; j++) {
            mean_cos += cos(theta[j]);
            mean_sin += sin(theta[j]);
        }
        mean_cos /= float(N);
        mean_sin /= float(N);
        float R   = sqrt(mean_cos*mean_cos + mean_sin*mean_sin);
        float Psi = atan(mean_sin, mean_cos);

        // Update phases: mean-field form dθ/dt = ω + K·R·sin(Ψ - θ)
        for (int i = 0; i < N; i++) {
            theta[i] += dt * (omega[i] + K * R * sin(Psi - theta[i]));
        }
    }

    // Final order parameter R and mean phase Ψ
    float final_cos = 0.0, final_sin = 0.0;
    for (int i = 0; i < N; i++) {
        final_cos += cos(theta[i]);
        final_sin += sin(theta[i]);
    }
    float R_final = sqrt(final_cos*final_cos + final_sin*final_sin) / float(N);

    // Dark background, slightly warmer near edges
    vec3 col = vec3(0.008, 0.008, 0.018);
    col += vec3(0.02, 0.01, 0.03) * length(p);

    // Draw each oscillator as a glowing disc
    for (int i = 0; i < N; i++) {
        float fi = float(i);
        // Fixed 2D position on a circle + jitter (like neurons scattered in cortex)
        float pos_angle = fi / float(N) * TAU + hash1(fi+200.0)*0.8;
        float pos_r     = 0.28 + hash1(fi+300.0)*0.16;
        vec2  pos       = vec2(cos(pos_angle)*pos_r, sin(pos_angle)*pos_r*0.7);

        float dist = length(p - pos);
        float disc_r = 0.010 + 0.010*R_final; // disc swells significantly with synchrony

        // Colour = phase mapped to hue
        // As synchrony builds, individual hues converge (mean phase Psi)
        float hue_indiv = fract(theta[i] / TAU);
        float hue_mean  = fract(atan(final_sin/float(N), final_cos/float(N)) / TAU);
        // Blend individual → mean hue as R increases (convergence is the story)
        float hue = mix(hue_indiv, hue_mean, R_final * R_final);
        // Keep saturation HIGH throughout — synchronised state = vivid not white
        float sat = 0.88 + 0.10*(1.0 - R_final*0.3);
        float val = 0.80 + 0.20*R_final;
        vec3 osc_col = hsv2rgb(vec3(hue, sat, val));

        // Core disc + glow halo
        float core = smoothstep(disc_r, disc_r*0.5, dist);
        float glow = exp(-dist*dist * 140.0) * (0.5 + 0.5*R_final); // glow stronger at sync
        float bloom= exp(-dist*dist * 25.0)  * 0.40 * R_final;      // wide bloom at sync

        col += osc_col * (core + glow + bloom);
    }

    // Global pulse: when R_final is high, whole screen brightens in sync
    float global_pulse = R_final * R_final * 0.15 * (0.5 + 0.5*sin(
        // pulse at mean frequency ≈ 0 (Lorentzian centred at 0) → slow beat
        atan(final_sin/float(N), final_cos/float(N))
    ));
    col += vec3(0.4, 0.5, 0.9) * global_pulse;

    // HUD: order parameter bar (bottom of screen)
    if (uv.y < 0.04) {
        float bar = smoothstep(R_final+0.005, R_final-0.005, uv.x);
        vec3 bar_col = mix(vec3(0.15,0.15,0.4), vec3(0.3,0.8,1.0), R_final);
        col = mix(col, bar_col, bar * smoothstep(0.04,0.02,uv.y));
        // K label zone
        float k_frac = K / (3.0*KC);
        col = mix(col, vec3(1.0,0.6,0.1)*0.8,
                  smoothstep(k_frac+0.005, k_frac-0.005, uv.x)*0.5
                  * smoothstep(0.04,0.02,uv.y));
    }

    // Tone map + gamma
    col = col / (col + 0.35);
    col = pow(max(col,0.0), vec3(0.82));

    fragColor = vec4(clamp(col,0.0,1.0),1.0);
}
