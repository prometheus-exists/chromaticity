// voronoi_heartbeat.glsl — Prometheus, 2026-04-20 v4 (final)
// Pulsing Voronoi cells — iridescent gemstone / living tissue
// MIT License
//
// 16 cells drift via smooth noise. Each cell is a polished dome:
//   - Hard specular highlight (Blinn-Phong, high exponent)
//   - Thin-film iridescence at cell edges (angle-dependent hue)
//   - Internal caustic flicker (hash noise modulated by pulse)
//   - Polyrhythmic pulse: cell area drives frequency
//   - Cells vary in height — some flat, some highly domed
//
// iTime: drift, pulse, light rotation, iridescence phase

#define N  16
#define PI 3.14159265358979
#define TAU 6.28318530717959

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1,311.7)), dot(p, vec2(269.5,183.3)));
    return -1.0 + 2.0*fract(sin(p)*43758.5453);
}
float hash1(float n) { return fract(sin(n*127.1)*43758.5453); }

float snoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f*f*(3.0-2.0*f);
    return mix(mix(dot(hash2(i+vec2(0,0)),f-vec2(0,0)),
                   dot(hash2(i+vec2(1,0)),f-vec2(1,0)),u.x),
               mix(dot(hash2(i+vec2(0,1)),f-vec2(0,1)),
                   dot(hash2(i+vec2(1,1)),f-vec2(1,1)),u.x),u.y);
}

// Jewel base colour from cell id
vec3 jewelBase(float id) {
    float hues[8];
    hues[0]=0.62; hues[1]=0.38; hues[2]=0.04; hues[3]=0.78;
    hues[4]=0.13; hues[5]=0.52; hues[6]=0.09; hues[7]=0.92;
    float h = hues[int(mod(id*8.0,8.0))];
    vec3 K = vec3(1.0,2.0/3.0,1.0/3.0);
    vec3 p = abs(fract(vec3(h)+K)*6.0-3.0);
    return 0.7*mix(vec3(1.0), clamp(p-1.0,0.0,1.0), 0.92);
}

// Thin-film iridescence: angle-dependent hue shift (rainbow at edges)
vec3 thinFilm(float cosTheta, float base_hue) {
    // Optical path difference ∝ 1/cos(θ) → hue shift at glancing angles
    float opd = 1.0 / (cosTheta + 0.1);
    float h = fract(base_hue + opd * 0.18 + iTime*0.03);
    vec3 K = vec3(1.0,2.0/3.0,1.0/3.0);
    vec3 p = abs(fract(vec3(h)+K)*6.0-3.0);
    return mix(vec3(1.0), clamp(p-1.0,0.0,1.0), 0.95);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    vec2 auv = vec2(uv.x*aspect, uv.y);

    // Seeds: golden-ratio distributed + slow noise drift
    vec2 seeds[N];
    float heights[N]; // per-cell dome height factor
    for (int i = 0; i < N; i++) {
        float fi = float(i);
        float angle = fi*2.399963;
        float r = 0.40*sqrt(fi/float(N));
        vec2 base = vec2(0.5*aspect + r*cos(angle)*aspect, 0.5+r*sin(angle));
        float t = iTime*0.07;
        seeds[i] = base + 0.055*vec2(snoise(vec2(fi*1.7,t)), snoise(vec2(fi*1.7+100.0,t)));
        heights[i] = 0.4 + 0.6*hash1(fi+7.3); // varied dome height
    }

    // Voronoi
    float d1=1e9, d2=1e9;
    int   id1=0;
    for (int i = 0; i < N; i++) {
        float d = length(auv - seeds[i]);
        if (d<d1){d2=d1; d1=d; id1=i;}
        else if (d<d2){d2=d;}
    }

    float edge_dist = d2 - d1;
    float dome_h = heights[id1];
    // Scale dome_k so Gaussian drops to ~0.1 at cell boundary.
    // Typical cell radius with N=16 in aspect-corrected ~1.4x1 space: ~0.12
    // Need k * r^2 ≈ 2.3  =>  k ≈ 2.3/0.0144 ≈ 160
    float dome_k = 80.0 + dome_h * 100.0;

    // Dome height map
    float cell_r = length(auv - seeds[id1]);
    float h = dome_h * exp(-dome_k * cell_r*cell_r);

    // Normal via central differences
    float eps = 0.005;
    float d1x=1e9, d1y=1e9;
    for (int i=0;i<N;i++) {
        d1x = min(d1x, length(vec2(auv.x+eps,auv.y)-seeds[i]));
        d1y = min(d1y, length(vec2(auv.x,auv.y+eps)-seeds[i]));
    }
    float hx = heights[id1]*exp(-dome_k*d1x*d1x);
    float hy = heights[id1]*exp(-dome_k*d1y*d1y);
    vec3  N3  = normalize(vec3((hx-h)/eps*2.5, (hy-h)/eps*2.5, 1.0));

    // Lighting: rotating key + ambient
    float la = iTime*0.2;
    vec3  L  = normalize(vec3(cos(la)*1.2, sin(la)*1.2, 1.8));
    vec3  V  = vec3(0.0,0.0,1.0);
    vec3  H  = normalize(L+V);

    float diff    = max(0.0, dot(N3, L));
    float spec    = pow(max(0.0, dot(N3, H)), 280.0); // hard specular — very tight
    float spec2   = pow(max(0.0, dot(N3, H)),  18.0); // soft secondary
    float cosT    = max(0.0, dot(N3, V));

    // Pulse: large cell = slow, small cell = fast
    float cell_area = d2/(d1+0.001);
    float freq  = 0.5 + 2.0/(cell_area*0.5+0.5);
    float phase = hash1(float(id1))*TAU;
    float pulse = 0.5 + 0.5*sin(iTime*freq*TAU*0.25 + phase);

    // Base colour
    vec3 base_col = jewelBase(hash1(float(id1)));
    float base_hue = hash1(float(id1)*3.7);

    // Thin-film at edges and grazing angles
    vec3 film = thinFilm(cosT, base_hue);
    float film_weight = pow(1.0-cosT, 2.5) * (0.5 + 0.5*smoothstep(0.0,0.04,edge_dist));

    // Internal caustic: flickering hash pattern deep in cell
    float caustic_noise = hash1(float(id1)*17.3 + floor(iTime*4.0)*0.1);
    float caustic = exp(-cell_r*cell_r*60.0) * caustic_noise * pulse * 0.3;

    // Dome-apex specular: brightest at peak of dome (where height is max)
    // The apex is at the seed position. Compute proximity to projected apex.
    vec2  apex_uv  = seeds[id1] / vec2(aspect, 1.0); // back to [0,1] space
    float apex_dist = length(uv - apex_uv);
    float apex_spec = exp(-apex_dist*apex_dist * 3200.0); // tight Gaussian at peak
    // Modulate by light visibility (fade when light is behind)
    float light_vis = max(0.0, dot(vec3(0,0,1), L));
    apex_spec *= light_vis * (0.6 + 0.4*dome_h);

    // Assemble
    float ambient = 0.12 + 0.08*pulse;
    vec3 col  = base_col * (ambient + diff*(0.3+0.2*pulse));
    col += spec  * vec3(1.0,0.97,0.90) * 1.0;          // rim specular
    col += spec2 * base_col * 0.20;                      // soft secondary
    col += apex_spec * vec3(1.0,0.98,0.92) * 1.8;      // hot-spot at dome peak
    col += film  * film_weight * 0.55;                   // iridescence
    col += caustic * vec3(1.0,0.95,0.8);                 // internal light
    col += h * base_col * 0.15;                          // dome self-illumination

    // Edge glow (cell boundary)
    float eg = exp(-edge_dist*70.0)*(0.35+0.25*pulse);
    col += eg * mix(vec3(0.9,0.95,1.0), film, 0.5);

    // Background
    float bg_mask = smoothstep(0.0, 0.018, edge_dist);
    col = mix(vec3(0.03,0.03,0.06), col, bg_mask);

    // Outer vignette
    vec2 uvn = uv - 0.5;
    col *= 1.0 - smoothstep(0.3, 0.72, length(uvn));

    // Tone map + gamma
    col = col/(col+0.6);
    col = pow(max(col,0.0), vec3(0.85));

    fragColor = vec4(clamp(col,0.0,1.0),1.0);
}
