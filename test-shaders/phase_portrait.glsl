// phase_portrait.glsl — Prometheus, 2026-04-20 v4 (final)
// Van der Pol oscillator phase portrait
// MIT License
//
// Six trajectories from different initial conditions converge on the stable
// limit cycle attractor. iTime advances the integration — watch chaos
// resolve into rhythm.
//
// Design:
//   - Background: LIC-style flow texture (multi-octave hash convolved along field)
//   - Trajectory trails: velocity-tapered thickness, age-faded
//   - Limit cycle: ring charge accumulates as trajectories settle
//   - Tone mapping: Reinhard on trajectories, gamma lift for depth

#define PI  3.14159265358979
#define TAU 6.28318530717959
#define MU  1.8

vec2 vdp(vec2 p) {
    return vec2(p.y, MU*(1.0-p.x*p.x)*p.y - p.x);
}

vec2 rk4(vec2 p, float dt) {
    vec2 k1 = vdp(p);
    vec2 k2 = vdp(p + dt*0.5*k1);
    vec2 k3 = vdp(p + dt*0.5*k2);
    vec2 k4 = vdp(p + dt*k3);
    return p + dt*(k1 + 2.0*k2 + 2.0*k3 + k4)/6.0;
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz)*6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p-K.xxx,0.0,1.0), c.y);
}

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453);
}

// LIC-style background: integrate a noise texture along the vector field
// Gives "brushed silk" appearance that follows local flow direction
float licBackground(vec2 uv) {
    float val = 0.0;
    float wt  = 0.0;
    vec2  p   = uv;
    float dt  = 0.04;
    // Forward integration
    for (int i = 0; i < 12; i++) {
        vec2 f = normalize(vdp(p)) * 0.001; // tiny step in phase-space units
        p += f * dt * 6.0;
        float w = float(12 - i) / 12.0;
        val += hash21(floor(p * 18.0)) * w;
        wt  += w;
    }
    // Backward integration
    p = uv;
    for (int i = 0; i < 12; i++) {
        vec2 f = normalize(vdp(p)) * 0.001;
        p -= f * dt * 6.0;
        float w = float(12 - i) / 12.0;
        val += hash21(floor(p * 18.0)) * w;
        wt  += w;
    }
    return val / wt;
}

// Velocity-based glow: thin+long when fast, thick+round when slow
float velGlow(vec2 uv, vec2 pos, vec2 vel) {
    float spd = length(vel);
    vec2  d   = uv - pos;
    // Align to velocity direction
    vec2  vdir = spd > 0.001 ? normalize(vel) : vec2(1.0, 0.0);
    vec2  vperp = vec2(-vdir.y, vdir.x);
    float along = dot(d, vdir);
    float perp  = dot(d, vperp);
    // Slow = fat circle, fast = thin elongated oval
    float len_scale = mix(0.008, 0.025, clamp(spd*0.15, 0.0, 1.0));
    float wid_scale = mix(0.006, 0.003, clamp(spd*0.15, 0.0, 1.0));
    float dist2 = (along*along)/(len_scale*len_scale) + (perp*perp)/(wid_scale*wid_scale);
    return 1.0 / (dist2 + 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 scale = vec2(3.2, 4.2);
    vec2 uv = (fragCoord / iResolution.xy - 0.5) * 2.0 * scale;

    // --- LIC background ---
    float lic = licBackground(uv);
    vec2  f   = vdp(uv);
    float spd = length(f);
    float ang = atan(f.y, f.x);
    float hue = fract(ang/TAU + iTime*0.012);
    // Speed-modulated brightness: fast regions brighter
    float val = 0.05 + 0.20*(1.0 - exp(-spd*0.4));
    // LIC texture modulates within each flow region
    float lic_mod = 0.7 + 0.3*lic;
    vec3 col = hsv2rgb(vec3(hue, 0.65, val * lic_mod));

    // --- Limit cycle reference ring ---
    // Elliptical approximation: semi-axes fitted to mu=1.8
    float lc_dist = abs(length(vec2(uv.x/2.05, uv.y/2.78)) - 1.0);
    float lc_charge = smoothstep(2.0, 14.0, iTime);
    float lc_glow = exp(-lc_dist*lc_dist * 100.0) * (0.04 + 0.22*lc_charge);
    col += lc_glow * hsv2rgb(vec3(0.62 + iTime*0.005, 0.4, 1.0));

    // --- Trajectories ---
    vec2 ics[6];
    ics[0] = vec2( 0.15,  0.15);
    ics[1] = vec2( 2.9,   0.05);
    ics[2] = vec2(-2.9,  -0.05);
    ics[3] = vec2( 0.05,  3.8);
    ics[4] = vec2( 1.6,  -2.7);
    ics[5] = vec2(-1.6,   2.7);

    vec3 tcs[6];
    tcs[0] = vec3(0.15, 0.92, 1.00); // cyan
    tcs[1] = vec3(1.00, 0.45, 0.10); // orange
    tcs[2] = vec3(0.30, 1.00, 0.42); // green
    tcs[3] = vec3(1.00, 0.22, 0.65); // pink
    tcs[4] = vec3(0.95, 0.90, 0.15); // yellow
    tcs[5] = vec3(0.65, 0.25, 1.00); // violet

    float dt   = 0.035;
    int   steps    = min(int(iTime / dt), 500);
    int   trail_len = 90;

    vec3 traj_col = vec3(0.0);

    for (int t = 0; t < 6; t++) {
        vec2 pos = ics[t];
        int  skip = max(0, steps - trail_len);
        // Fast-forward
        for (int i = 0; i < 500; i++) {
            if (i >= skip) break;
            pos = rk4(pos, dt);
        }
        // Draw trail with velocity-tapered glow
        vec2 prev = pos;
        for (int i = 0; i < 90; i++) {
            if (i + skip >= steps) break;
            vec2 next = rk4(pos, dt);
            vec2 vel  = (next - pos) / dt;
            float age = float(i) / float(trail_len);
            float brightness = pow(1.0 - age, 2.0);
            traj_col += brightness * tcs[t] * velGlow(uv, pos, vel);
            // Head: extra bright leading point
            if (i == min(steps - skip - 1, trail_len - 1)) {
                traj_col += 2.5 * tcs[t] * velGlow(uv, pos, vel * 0.3);
            }
            pos = next;
        }
    }

    // Tone-map trajectories (Reinhard per-channel)
    traj_col = traj_col / (traj_col + 0.8);
    col += traj_col;

    // --- Vignette ---
    vec2 uv_n = fragCoord/iResolution.xy - 0.5;
    float vig = 1.0 - smoothstep(0.28, 0.72, length(uv_n * vec2(1.0, 1.25)));
    col *= 0.25 + 0.75*vig;

    // Final tone map + gamma
    col = col / (col + 0.55);
    col = pow(max(col, 0.0), vec3(0.82));

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
