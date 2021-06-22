
//-------------------------------------------------
//Uniforms
//-------------------------------------------------

uniform sampler2D new;
uniform sampler2D acc;
uniform float iFrame;
uniform vec3 iResolution;


//-------------------------------------------------
//Read in the Data
//-------------------------------------------------

vec4 newFrame(vec2 fragCoord){
    return texture(new, fragCoord / iResolution.xy);
}

vec4 accFrame(vec2 fragCoord){
    return texture(acc, fragCoord / iResolution.xy);
}






//-------------------------------------------------
//Do the Accumulation
//-------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord )
{
    //get new and old frames
    vec4 new = newFrame(fragCoord);
    vec4 prev = accFrame(fragCoord);

    //blend them together
    float blend = (iFrame < 2. || prev.a == 0.0f) ? 1.0f :  1. / (1. + 1./prev.a);
    vec3 color = mix(prev.rgb,new.rgb,blend);

    // output the result
    fragColor = vec4(color, blend);
}








void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
}
