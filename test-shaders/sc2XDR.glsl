

/*
    Raymarch in Buffer A, Image is all @Shane from here:
    https://www.shadertoy.com/view/XsKGRW
    
    I tweaked a couple things, so please see Shane's for reference.
    
*/

const float SAMPLES = 16.;
float hash( vec2 p ){ return fract(sin(dot(p, vec2(41, 289)))*45758.5453); }

void mainImage( out vec4 o, vec2 u ){
    
    u /= iResolution.xy;
    
    float decay = .5,
          density = .5, 
          weight = .2,
          i;
          
    vec3 l = vec3(cos(iTime), sin(iTime/1.4), 1e1);
    vec2 tuv =  u - .5 - l.xy*.45,
         v = tuv*density/SAMPLES;
    vec4 c = texture(iChannel0, u)*0.5;
    u += v*(hash(u + fract(iTime))*2. - 1.);
    for(; i < SAMPLES; i++){
        u -= v;
        c += texture(iChannel0, u) * weight;
        weight *= decay;
    }
 
    o = sqrt(smoothstep(0., 1., c));
}
