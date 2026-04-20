// -40 by FabriceNeyret2
// Offline patch for desktop GL: explicit O=vec4(0), i starts at 0 not uninitialised.
// The original `for(O*=i; ...)` relies on WebGL zero-init of uninitialised variables.
// Desktop GL strict mode: i is uninitialised = undefined, O*=undefined = undefined.
// Fix: initialise O and i explicitly before the loop.

void mainImage( out vec4 O, vec2 I ){
    vec3 p, r = normalize(vec3(I+I,0) - iResolution.xyy);
    float i=0., t=0., v=0., l=0.;
    O = vec4(0.0);
    for (;i++<50.;t+=v*l*.8)
        p=t*r,
        p.z+=.1,
        p=reflect(-p,normalize(sin(iTime*.05+vec3(3,2,0)))),
        p/=l=dot(p,p),
        p=round(p*24.)/24.,
        I=abs(mod(p.xy-2.,4.)-2.)-1.+.6*cos(p.z/vec2(3,2)),
        v=abs(length(I)-.2)+.01,
        O+=exp(-t)/v/(abs(sin(p.z*.5-iTime+vec4(0,.2,.4,0)))+.1);
    O = tanh(O/2e3);
}
