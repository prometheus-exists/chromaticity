// curl_flow.glsl — Prometheus, 2026-04-20 v6 (final)
// Curl noise — aurora borealis / deep-space plasma
// MIT License
//
// Core principle: BLACK background, ADDITIVE light emission.
// Filaments are bright, space is dark. No tone-mapping of base layer.
// Multi-octave curl noise (Bridson 2007) drives flow.
// iTime cascades turbulence from large eddies to fine structure.

#define PI  3.14159265358979
#define TAU 6.28318530717959

vec2 gradHash(vec2 p) {
    p  = fract(p * vec2(0.1031, 0.1030));
    p += dot(p, p.yx + 19.19);
    return normalize(fract((p.xx+p.yx)*p.xy) * 2.0 - 1.0);
}

float perlin(vec2 p) {
    vec2 i=floor(p), f=fract(p);
    vec2 u=f*f*f*(f*(f*6.0-15.0)+10.0);
    return mix(
        mix(dot(gradHash(i),f),         dot(gradHash(i+vec2(1,0)),f-vec2(1,0)),u.x),
        mix(dot(gradHash(i+vec2(0,1)),f-vec2(0,1)),dot(gradHash(i+vec2(1,1)),f-vec2(1,1)),u.x),u.y)*0.5+0.5;
}

float fbm4(vec2 p, float t_offset) {
    float v=0.0,a=0.52;
    mat2 R=mat2(0.8,0.6,-0.6,0.8);
    for(int i=0;i<4;i++){v+=a*perlin(p+vec2(t_offset,0));p=R*p*2.05;a*=0.5;}
    return v;
}

// Curl of scalar potential psi = fbm
vec2 curlField(vec2 p, float t) {
    float e=0.001;
    float turb=smoothstep(0.0,20.0,t);

    // Three scale layers — fine scales activate with time
    float s1=2.5, s2=5.5, s3=12.0;
    float t1=t*0.10, t2=t*0.20, t3=t*0.36*turb;
    float w1=1.0, w2=0.55, w3=0.30*turb;

    float pu = w1*fbm4(p*s1+vec2(0,e),t1)+w2*fbm4(p*s2+vec2(0,e),t2)+w3*fbm4(p*s3+vec2(0,e),t3);
    float pd = w1*fbm4(p*s1-vec2(0,e),t1)+w2*fbm4(p*s2-vec2(0,e),t2)+w3*fbm4(p*s3-vec2(0,e),t3);
    float pr = w1*fbm4(p*s1+vec2(e,0),t1)+w2*fbm4(p*s2+vec2(e,0),t2)+w3*fbm4(p*s3+vec2(e,0),t3);
    float pl = w1*fbm4(p*s1-vec2(e,0),t1)+w2*fbm4(p*s2-vec2(e,0),t2)+w3*fbm4(p*s3-vec2(e,0),t3);

    return vec2((pu-pd),(pl-pr)) / (2.0*e) * 0.20;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv  = fragCoord / iResolution.xy;
    float ar = iResolution.x / iResolution.y;
    vec2 p   = vec2(uv.x*ar, uv.y);

    // Backward trace to rest position
    vec2 pos = p;
    for (int i=0;i<55;i++){
        pos -= curlField(pos, iTime - float(i)*0.022) * 0.022;
    }

    // Current velocity
    vec2  v   = curlField(p, iTime);
    float spd = length(v);

    // Vorticity (z-component of curl of v)
    float ev=0.007;
    float dvydx=(curlField(p+vec2(ev,0),iTime).y-curlField(p-vec2(ev,0),iTime).y)/(2.0*ev);
    float dvxdy=(curlField(p+vec2(0,ev),iTime).x-curlField(p-vec2(0,ev),iTime).x)/(2.0*ev);
    float vort=abs(dvydx-dvxdy);

    // Filament mask: only fast-moving regions emit light
    float emit = pow(smoothstep(0.02,0.22,spd), 1.2);

    // Colour: aurora palette — green oxygen / violet nitrogen / white cores
    // Hue from rest-position fbm (material identity, moves with flow)
    float mat_id = fbm4(pos*1.4, 0.0);

    vec3 c_green = vec3(0.08, 1.00, 0.45);
    vec3 c_violet= vec3(0.55, 0.15, 1.00);
    vec3 c_cyan  = vec3(0.05, 0.75, 1.00);
    vec3 c_white = vec3(0.90, 1.00, 0.85);

    // Map mat_id + slow time drift to palette
    float h = fract(mat_id + iTime*0.018);
    vec3 aurora;
    if      (h < 0.4) aurora = mix(c_green,  c_cyan,   h/0.4);
    else if (h < 0.7) aurora = mix(c_cyan,   c_violet, (h-0.4)/0.3);
    else              aurora = mix(c_violet,  c_green,  (h-0.7)/0.3);

    // Vortex cores: white-hot
    aurora = mix(aurora, c_white, clamp(vort*0.07,0.0,0.7));

    // Speed tint: fast = hotter (shift toward white)
    aurora = mix(aurora, c_white, smoothstep(0.5,1.0,spd*2.0)*0.3);

    // Emit: purely additive into black space
    vec3 col = vec3(0.005, 0.006, 0.015); // near-black base (stars)
    col += aurora * emit * 2.2;

    // Compositional focal point: one bright core region + dark surround
    // Core drifts slowly on a figure-8 path (Lissajous)
    float cx = 0.5 + 0.18*sin(iTime*0.11);
    float cy = 0.5 + 0.14*sin(iTime*0.17 + 1.0);
    float core_dist = length(uv - vec2(cx,cy));
    float core_bright = exp(-core_dist*core_dist * 8.0);  // wide, soft focal glow
    float dark_surround = 0.15 + 0.85*smoothstep(0.48, 0.15, core_dist); // dark edges
    col *= dark_surround;
    col += aurora * emit * core_bright * 1.2; // extra emission at focal core

    // Curtain: aurora bands stronger in middle height range
    float curtain = 0.5 + 0.5*exp(-pow((uv.y-0.52)*2.2,2.0));
    col *= curtain;

    // Fake bloom: add softened copy via nearby samples
    float spd_n = length(curlField(p+vec2( 0.008,0),iTime));
    float spd_s = length(curlField(p+vec2(-0.008,0),iTime));
    float spd_e = length(curlField(p+vec2(0, 0.008),iTime));
    float spd_w = length(curlField(p+vec2(0,-0.008),iTime));
    float bloom_emit = pow(smoothstep(0.05,0.5,(spd_n+spd_s+spd_e+spd_w)*0.25),1.4);
    col += aurora * bloom_emit * 0.22; // soft halo around filaments

    // Gamma only — NO tone mapping of black base (keeps darkness dark)
    col = pow(max(col,0.0), vec3(0.80));

    fragColor = vec4(clamp(col,0.0,1.0),1.0);
}
