// sc2XDR — Buffer A (scene renderer)
// Fractal tunnel with recursive folding + rotation
// Credit: @Shane (god rays post-process in Image pass)

void mainImage(out vec4 o, vec2 u) {
    float c,i,d,s,g;
    u.y /= 1.5;
    vec3 q,p = iResolution,
         D =  normalize(vec3(u = (u+u-p.xy)/p.y, 1));
    D.y/=1.75;
    for(o*=i; i++<1e2;
        d += s = max(s, q.y),
        o += 1./max(s, .001) 
    )
        for(q = p = D * d/1.5,
            p.y += 1e1,
            q.z = p.z += iTime * 1e1,
            c = 1e2, s = 0.; c > 1.; c *= .4
        )
            q = abs(fract(q/c)*c - c/2.) - c/1e1,
            s = max(s, min(q.x, min(q.y, q.z))-c/1e1),
            q.yz *= mat2(cos(1.14 + vec4(0,33,11,0))),
            s = max(s, min(q.x, min(q.y, q.z))-c/1e1),
            q = p;

    o /= 1e5;
    
    // @Shane, ty
    vec4 bg = vec4(4, 2, 1, 0);
    // Very hacky faux AO. 
    o *= mix(bg/3., vec4(1), smoothstep(.3, .7, o));
    o = mix(o, bg, smoothstep(0., 2e3-1e3, d));    
    o = tanh(o/length(u-.5));
}
