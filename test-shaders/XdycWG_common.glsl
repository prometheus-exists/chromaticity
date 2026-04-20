// XdycWG — Common tab
// Created by anatole duprat - XT95/2018
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// math
#define time iTime
#define PI 3.141592653589
#define saturate(x) clamp(x,0.,1.)
float hash( vec3 x );
float hash( vec2 p );
float hash( float p );
float hash2Interleaved( vec2 x );
float noise( vec3 x );
vec4 noised( vec3 x );
mat2 rotate( float t );

// mapping
vec3 randomSphereDir( vec2 rnd );
vec3 randomHemisphereDir( vec3 dir, float i );
vec4 tex3D( sampler2D tex, vec3 p, vec3 n );
vec3 bumpMapping( sampler2D tex, vec3 p, vec3 n, float bf );

// tone mapping
vec3 acesToneMapping( vec3 col );
vec3 filmicToneMapping( vec3 col );

float hash( vec3 p ) { return fract(sin(dot(p,vec3(127.1,311.7, 74.7)))*43758.5453123); }
float hash( vec2 p ) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453123); }
float hash( float p ) { return fract(sin(p)*43758.5453123); }
float hash2Interleaved( vec2 x ) {
    vec3 magic = vec3( 0.06711056, 0.00583715, 52.9829189 );
    return fract( magic.z * fract( dot( x, magic.xy ) ) );
}

vec4 noised( vec3 x ) {
    vec3 p = floor(x); vec3 w = fract(x);
    vec3 u = w*w*w*(w*(w*6.0-15.0)+10.0);
    vec3 du = 30.0*w*w*(w*(w-2.0)+1.0);
    float a=hash(p+vec3(0,0,0)),b=hash(p+vec3(1,0,0)),c=hash(p+vec3(0,1,0)),d=hash(p+vec3(1,1,0));
    float e=hash(p+vec3(0,0,1)),f=hash(p+vec3(1,0,1)),g=hash(p+vec3(0,1,1)),h=hash(p+vec3(1,1,1));
    float k0=a,k1=b-a,k2=c-a,k3=e-a,k4=a-b-c+d,k5=a-c-e+g,k6=a-b-e+f,k7=-a+b+c-d+e-f-g+h;
    return vec4(-1.0+2.0*(k0+k1*u.x+k2*u.y+k3*u.z+k4*u.x*u.y+k5*u.y*u.z+k6*u.z*u.x+k7*u.x*u.y*u.z),
                2.0*du*vec3(k1+k4*u.y+k6*u.z+k7*u.y*u.z, k2+k5*u.z+k4*u.x+k7*u.z*u.x, k3+k6*u.x+k5*u.y+k7*u.x*u.y)).yzwx;
}
float noise( vec3 x ) {
    vec3 p=floor(x); vec3 w=fract(x);
    vec3 u=w*w*w*(w*(w*6.0-15.0)+10.0);
    float a=hash(p+vec3(0,0,0)),b=hash(p+vec3(1,0,0)),c=hash(p+vec3(0,1,0)),d=hash(p+vec3(1,1,0));
    float e=hash(p+vec3(0,0,1)),f=hash(p+vec3(1,0,1)),g=hash(p+vec3(0,1,1)),h=hash(p+vec3(1,1,1));
    float k0=a,k1=b-a,k2=c-a,k3=e-a,k4=a-b-c+d,k5=a-c-e+g,k6=a-b-e+f,k7=-a+b+c-d+e-f-g+h;
    return -1.0+2.0*(k0+k1*u.x+k2*u.y+k3*u.z+k4*u.x*u.y+k5*u.y*u.z+k6*u.z*u.x+k7*u.x*u.y*u.z);
}
mat2 rotate( float t ) { float a=cos(t),b=sin(t); return mat2(a,b,-b,a); }

vec3 randomSphereDir( vec2 rnd ) { float s=rnd.x*PI*2.,t=rnd.y*2.-1.; return vec3(sin(s),cos(s),t)/sqrt(1.0+t*t); }
vec3 randomHemisphereDir( vec3 dir, float i ) { vec3 v=randomSphereDir(vec2(hash(i+1.),hash(i+2.))); return v*sign(dot(v,dir)); }
vec4 tex3D( sampler2D tex, vec3 p, vec3 n ) { n=abs(n); return (texture(tex,p.yz)*n.x+texture(tex,p.xz)*n.y+texture(tex,p.xy)*n.z)/3.; }
vec3 bumpMapping( sampler2D tex, vec3 p, vec3 n, float bf ) {
    const vec2 e=vec2(0.001,0);
    mat3 m=mat3(tex3D(tex,p-e.xyy,n).rgb, tex3D(tex,p-e.yxy,n).rgb, tex3D(tex,p-e.yyx,n).rgb);
    vec3 g=vec3(0.299,0.587,0.114)*m;
    g=(g-dot(tex3D(tex,p,n).rgb,vec3(0.299,0.587,0.114)))/e.x;
    g-=n*dot(n,g);
    return normalize(n+g*bf);
}
vec3 acesToneMapping( vec3 col ) { const float a=2.51,b=0.03,c=2.43,d=0.59,e=0.14; return (col*(a*col+b))/(col*(c*col+d)+e); }
vec3 filmicToneMapping( vec3 col ) { col=max(vec3(0.),col-vec3(0.004)); return (col*(6.2*col+.5))/(col*(6.2*col+1.7)+0.06); }
