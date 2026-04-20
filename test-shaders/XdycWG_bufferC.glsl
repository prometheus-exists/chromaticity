// XdycWG — Buffer C (vertical bilateral bloom blur)
void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    vec2 invRes=vec2(1.)/iResolution.xy, uv=fragCoord*invRes, offset=vec2(0.,3.)*invRes;
    vec3 col=vec3(0);
    for(float i=-6.;i<=6.;i+=1.) col+=texture(iChannel0,uv+offset*i).rgb;
    fragColor=vec4(col/12.,1.);
}
