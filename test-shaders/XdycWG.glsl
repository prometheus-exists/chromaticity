// XdycWG — Image pass (DoF + bloom composite)
// Created by anatole duprat - XT95/2018
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
// Pass order: Buffer A (scene) → Buffer B (h-blur) → Buffer C (v-blur) → Image (DoF + bloom)
// iChannel0 = Buffer A output, iChannel1 = Buffer C output

vec3 farBlur(vec2 uv, vec2 invRes, float r) {
    const float gauss[4]=float[4](1.0,0.38774,0.24477,0.06136);
    vec3 c=vec3(0.); float w=0.;
    for(int x=-3;x<=3;x++) for(int y=-3;y<=3;y++) {
        vec4 tap=textureLod(iChannel0,uv+vec2(float(x),float(y))*invRes,2.);
        float match=tap.a*gauss[abs(x)]*gauss[abs(y)]; w+=match; c+=tap.rgb*match;
    }
    if(w==0.)return vec3(0.);
    return c/w;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    vec2 invRes=vec2(1.)/iResolution.xy, uv=fragCoord*invRes;
    float coc=texture(iChannel0,uv).a;
    vec3 col=mix(texture(iChannel0,uv).rgb,farBlur(uv,invRes,coc),coc);
    vec3 bloom=texture(iChannel1,uv).rgb;
    bloom=mix(bloom,vec3(dot(bloom,bloom)),vec3(.3));
    col+=pow(bloom,vec3(2.))*.7;
    col*=saturate(pow(uv.x*uv.y*(1.-uv.x)*(1.-uv.y)*100.,.2));
    col=acesToneMapping(col);
    fragColor=vec4(col,1.);
}
