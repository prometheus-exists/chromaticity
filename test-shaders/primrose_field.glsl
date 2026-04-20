// primrose_field.glsl — Prometheus, 2026-04-20 final
// Primrose field with Kitaoka peripheral drift illusion
// MIT License
//
// A meadow of primroses at golden hour.
// Each flower carries Kitaoka's tangential sawtooth luminance gradient —
// the asymmetric dark→light sweep around the petal ring creates illusory
// rotation in peripheral vision (Kitaoka & Ashida 2003).
// iTime: wind sway + slow phase walk that animates the drift.

#define TAU   6.28318530717959
#define N_PETALS 6

float hash1(float n) { return fract(sin(n*127.1)*43758.5453); }
float hash1b(float n){ return fract(sin(n*311.7)*17341.23); }

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0,2.0/3.0,1.0/3.0,3.0);
    vec3 p = abs(fract(c.xxx+K.xyz)*6.0-K.www);
    return c.z*mix(K.xxx,clamp(p-K.xxx,0.0,1.0),c.y);
}

// Draw one primrose flower at flower-local normalised coords fp.
// flower_id used for colour variety. Returns modified colour.
vec3 primrose(vec3 col, vec2 fp, float fid, float iTime, float lf) {
    float petal_len = 0.70;
    float petal_wid = 0.30;
    float petal_off = 0.44;

    // Alternate petal colour: cream / pink / violet
    float hs = hash1(fid + 91.0);
    float hue = hs < 0.35 ? 0.08          // cream/white
              : hs < 0.65 ? 0.91          // pink
                           : 0.77;         // violet
    float sat = (0.55 + 0.30*hash1(fid+31.0)) * mix(1.0, 0.6, lf*0.4);

    for (int pi = 0; pi < N_PETALS; pi++) {
        float pa    = float(pi) * TAU / float(N_PETALS);
        vec2  pdir  = vec2(cos(pa), sin(pa));
        vec2  pperp = vec2(-sin(pa), cos(pa));
        vec2  ploc  = fp - pdir * petal_off;
        float along = dot(ploc, pdir);
        float perp  = dot(ploc, pperp);
        float pd    = length(vec2(perp/petal_wid, along/petal_len)) - 1.0;

        if (pd < 0.08) {
            float aa = smoothstep(0.08, -0.02, pd);

            // Kitaoka tangential sawtooth:
            // Luminance sweeps CCW around flower centre — creates drift signal
            float angle = atan(fp.y, fp.x);
            float t = fract(angle/TAU + iTime*0.05);
            // 4-zone asymmetric ramp — MAX CONTRAST version
            // Black(0.0) → Dark(0.12) → White(1.0) → Mid(0.55)
            // Steep black→white is the motion-signal trigger
            float lum;
            if      (t < 0.12) lum = mix(0.00, 0.12, t/0.12);
            else if (t < 0.48) lum = mix(0.12, 1.00, (t-0.12)/0.36);
            else if (t < 0.75) lum = mix(1.00, 0.55, (t-0.48)/0.27);
            else               lum = mix(0.55, 0.00, (t-0.75)/0.25);

            vec3 pcol = hsv2rgb(vec3(hue, sat*(0.2+0.8*(1.0-lum*0.4)), lum));
            col = mix(col, pcol, aa);
        }
    }

    // Yellow centre disc
    float cd = length(fp);
    if (cd < 0.30)
        col = mix(col, hsv2rgb(vec3(0.13, 0.88, 0.88 + 0.12*sin(iTime*2.0+fid))),
                  smoothstep(0.30, 0.16, cd));

    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float ar = iResolution.x / iResolution.y;
    vec2 p = vec2(uv.x * ar, uv.y);

    // Scene: sky top → horizon → grass bottom
    float horiz = 0.42;

    vec3 col;
    if (uv.y > horiz) {
        // Sky: golden hour — deep amber at top, warm peach at horizon
        vec3 sky_top = vec3(0.85, 0.48, 0.18);
        vec3 sky_mid = vec3(0.96, 0.76, 0.42);
        vec3 sky_hor = vec3(0.98, 0.90, 0.72);
        float st = smoothstep(horiz, 1.0, uv.y);
        col = st < 0.5 ? mix(sky_hor, sky_mid, st*2.0)
                       : mix(sky_mid, sky_top, (st-0.5)*2.0);
        // Sun disc upper-right
        float sun_d = length(uv - vec2(0.78, 0.82));
        col = mix(col, vec3(1.0, 0.95, 0.70), exp(-sun_d*sun_d*60.0)*0.9);
        col += vec3(0.18, 0.10, 0.02) * exp(-sun_d*sun_d*12.0);
        // Clouds — warm-tinted
        float cx = fract(uv.x*2.1 + iTime*0.007)*2.0-1.0;
        float cloud = exp(-(cx*cx*1.2 + (uv.y-0.68)*(uv.y-0.68)*7.0)) * 0.22;
        float cx2 = fract(uv.x*1.5+0.6 + iTime*0.005)*2.0-1.0;
        cloud += exp(-(cx2*cx2*1.8 + (uv.y-0.76)*(uv.y-0.76)*9.0)) * 0.14;
        col = mix(col, vec3(1.0, 0.95, 0.82), cloud);
        // Distant tree-line silhouette just above horizon
        // Trees poke up from horiz into sky
        float tree_h = horiz + 0.025 + 0.022*abs(sin(uv.x*14.0))*abs(sin(uv.x*5.3+0.8));
        float in_tree = smoothstep(tree_h, tree_h-0.010, uv.y) * smoothstep(horiz-0.005, horiz+0.005, uv.y);
        col = mix(col, vec3(0.06, 0.13, 0.04), in_tree);
    } else {
        // Grass: warm golden tinge near horizon, rich green foreground
        col = mix(vec3(0.14, 0.40, 0.08), vec3(0.44, 0.54, 0.24),
                  smoothstep(0.0, horiz, uv.y));
        // Warm evening light on grass
        col = mix(col, col * vec3(1.15, 1.05, 0.82), smoothstep(0.0, horiz, uv.y)*0.4);
        // Fine grass texture
        float gv = 0.86 + 0.14*fract(sin(p.x*34.7+p.y*19.3)*43758.5);
        col *= gv;
    }

    float wind = iTime * 0.30;

    // Flowers: 56 total, randomly scattered in grass zone
    // Render back-to-front using 6 y-depth passes
    for (int pass = 5; pass >= 0; pass--) {
        float y_lo = float(pass)   * horiz / 6.0;
        float y_hi = float(pass+1) * horiz / 6.0;

        for (int fi = 0; fi < 56; fi++) {
            float fid = float(fi);
            float fy  = hash1(fid + 17.3) * horiz;
            if (fy < y_lo || fy >= y_hi) continue;

            float fx  = hash1(fid + 3.7) * ar;
            float lf  = fy / horiz;  // 0=near bottom, 1=near horizon

            // Perspective scale: near=big, far=small
            float sc  = mix(0.072, 0.022, lf) * (0.75 + 0.45*hash1(fid+5.0));

            // Wind sway
            float sx  = 0.013 * sin(wind*(0.5+0.5*hash1(fid*3.1)) + fid*0.7) * (1.0-lf*0.3);
            vec2  centre = vec2(fx + sx, fy);

            vec2 fp = (p - centre) / sc;
            if (length(fp) > 2.4) continue;

            // Shadow on grass — sun upper-right, shadow falls lower-left
            vec2 shp = fp - vec2(-0.25, -0.40);
            float sha = smoothstep(0.48, -0.02, length(vec2(shp.x*0.5, shp.y*0.28))) * 0.22;
            col = mix(col, vec3(0.04, 0.14, 0.03), sha);

            // Stem
            float ty   = clamp(-fp.y / 0.90, 0.0, 1.0);
            float stem = length(fp - vec2(0.0, -ty*0.90)) - 0.08;
            col = mix(col,
                      mix(vec3(0.17,0.44,0.11), vec3(0.10,0.32,0.07), ty),
                      smoothstep(0.04, -0.01, stem) * (1.0-lf*0.25));

            // Draw flower (illusion petals)
            col = primrose(col, fp, fid, iTime, lf);
        }
    }

    // Atmospheric haze toward horizon — stronger for depth
    col = mix(col, vec3(0.80, 0.84, 0.68), smoothstep(0.05, horiz, uv.y) * 0.40);

    col = pow(max(col, 0.0), vec3(0.90));
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
