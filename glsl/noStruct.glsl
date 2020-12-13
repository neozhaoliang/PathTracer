 #include <common>

uniform vec3 iResolution;
uniform float iTime;
uniform sampler2D sky;
uniform sampler2D acc;
uniform float iFrame;

// constants
float eps=0.0001;
int maxMarchSteps=300;
float maxDist=100.;
float distToViewer;
bool isSky=false;
float fov=100.;


vec3 pixelColor=vec3(0.);
vec3 lightColor=vec3(1.);
vec3 albedo;
vec3 emissive;

vec2 toSphCoords(vec3 v){
float theta=atan(-v.z,v.x);
float phi=acos(v.y);
return vec2(theta,phi);
}




vec3 skyTex(vec3 v){

vec2 angles=toSphCoords(v);
float x=(angles.x+3.1415)/(2.*3.1415);
float y=1.-angles.y/3.1415;

return texture(sky,vec2(x,y)).rgb;

}






vec3 LessThan(vec3 f, float value)
{
    return vec3(
        (f.x < value) ? 1.0f : 0.0f,
        (f.y < value) ? 1.0f : 0.0f,
        (f.z < value) ? 1.0f : 0.0f);
}


vec3 LinearToSRGB(vec3 rgb)
{
    rgb = clamp(rgb, 0.0f, 1.0f);
    
    return mix(
        pow(rgb, vec3(1.0f / 2.4f)) * 1.055f - 0.055f,
        rgb * 12.92f,
        LessThan(rgb, 0.0031308f)
    );
}

vec3 SRGBToLinear(vec3 rgb)
{   
    rgb = clamp(rgb, 0.0f, 1.0f);
    
    return mix(
        pow(((rgb + 0.055f) / 1.055f), vec3(2.4f)),
        rgb / 12.92f,
        LessThan(rgb, 0.04045f)
	);
}















uint wang_hash(inout uint seed)
{
    seed = uint(seed ^ uint(61)) ^ uint(seed >> uint(16));
    seed *= uint(9);
    seed = seed ^ (seed >> 4);
    seed *= uint(0x27d4eb2d);
    seed = seed ^ (seed >> 15);
    return seed;
}
 
float RandomFloat01(inout uint state)
{
    return float(wang_hash(state)) / 4294967296.0;
}
 
vec3 RandomUnitVector(inout uint state)
{
    float z = RandomFloat01(state) * 2.0f - 1.0f;
    float a = RandomFloat01(state) * 6.28;
    float r = sqrt(1.0f - z * z);
    float x = r * cos(a);
    float y = r * sin(a);
    return vec3(x, y, z);
}







//tangent vector
struct Vector{
    vec3 pos;
    vec3 dir; 
};


//
//Vector add(Vector v, Vector w){
//    //this only makes sense if v and w are based at the same point
//    return Vector(v.pos, v.dir+w.dir);
//}
//
//Vector negate(Vector v){
//    return Vector(v.pos,-v.dir);
//}
//
//Vector sub(Vector v, Vector w){
//    return add(v,negate(w));
//}
//
//Vector normalize(inout Vector v){
//   return Vector(v.pos,normalize(v.dir));
//}
//
//Vector clone(Vector v){
//    return v;
//}
//
//float dot(Vector v, Vector w){
//    return dot(v.dir,w.dir);
//}
//
//float cosAng(Vector v, Vector w){
//    return dot(normalize(v),normalize(w));
//}
//
////small shift in the location of a point
//vec3 shiftPoint(vec3 p, vec3 v, float t){
//    return p+eps*v;
//}
//
//Vector shift(Vector tv, vec3 dir, float t){
//    return Vector(tv.pos+eps*dir,tv.dir);
//}


//actually flowing along a geodesic
Vector flow(Vector tv, float t){
    //flow distance t in direction tv
    vec3 res=tv.pos+t*tv.dir;
    return Vector(res,tv.dir);
}

void nudge(Vector v, vec3 dir){
    v.pos+=dir*0.01;
}



struct Path{
    Vector tv;
    vec3 pixel;//pixel color
    vec3 light;
};




Path initializePath(Vector tv){
    Path p;
    p.tv=tv;//set the initial direction
    p.pixel=vec3(0.);//set the pixel black
    p.light=vec3(1.);//set the light white
    
    return p;
}


struct localData{
    Vector normal;
    Vector reflect;
    Vector refract;
    vec3 emit;
    vec3 diffuse;
    bool isSky;
};







//actually flowing along a geodesic
vec3 flow(vec3 pos, vec3 dir, float t){
    //flow distance t in direction tv
    vec3 res=pos+t*dir;
    return res;
}





float sphereSDF(vec3 pos,vec3 dir, vec3 center, float rad){
    //if you are looking away from the sphere, stop
    if(dot(dir,pos-center)>0.){return maxDist;}
    //else return distance to closest point
    return length(pos-center)-rad;
}

vec3 sphereNormal(vec3 pos, vec3 dir, vec3 center){
    return normalize(pos-center);
}







float planeSDF(vec3 pos, vec3 dir, vec3 normal, float D){
    //does not need to be a unit normal vector
    //D is the constant in ax+by+cz+d=0
    if(dot(dir,normal)>0.){return maxDist;}
    
    //otherwise give distance to closest point
   float d=dot(pos,normal)+D;
   d= d/length(normal);
    return d;
}

vec3 planeNormal(vec3 pos, vec3 dir,vec3 normal, float D){
    return  normal;
}





//extra data
float sceneSDF(vec3 pos, vec3 dir, inout vec3 normal, inout vec3 diffuse, inout vec3 emit){
    
    vec3 center1=vec3(0,0,-2.);
    float dist= sphereSDF(pos,dir, center1,0.5);
    
    if(dist<eps){
        normal=sphereNormal(pos,dir,center1);
        diffuse=vec3(0.,0.2,0.5);
        emit=vec3(0.0);
        return dist;
    }
    
    
    //the light source
    vec3 center2=vec3(0.5,0.2,-1);
    float dist2=sphereSDF(pos,dir, center2,0.1);
    
    if(dist2<eps){
        normal=sphereNormal(pos,dir,center2);
        diffuse=vec3(1.);
        emit=vec3(.5);
        return dist2;
    }
    
    vec3 pNormal=vec3(0,1,0.1);
        float dist3=planeSDF(pos,dir, pNormal,0.65);
    
    if(dist3<eps){
       normal=planeNormal(pos,dir,pNormal,0.65);
        diffuse=vec3(1.,0.,0.2);
        emit=vec3(0.0);
        return dist3;
    }
    
    
    return min(min(dist,dist2),dist3);

}






float raymarch(inout vec3 pos, inout vec3 dir, inout vec3 normal, inout vec3 diffuse,inout vec3 emit){

    distToViewer=0.;
    float marchStep = 0.;
    float depth=0.;

        for (int i = 0; i < maxMarchSteps; i++){
            
                float localDist = sceneSDF(pos,dir,normal,diffuse, emit);
           
                if (localDist < eps){
                    isSky=false;
                    return depth;
                }
                marchStep =localDist;
               depth += marchStep;
            if(depth>maxDist){
                isSky=true;
                return maxDist;
            }
            pos = flow(pos,dir, marchStep);
        }
    
    //if you hit nothing
    isSky=true;
    return maxDist;
}





//march in direction of tv until you hit an object, do color computations at that object
void stepForward(inout vec3 pos, inout vec3 dir, inout vec3 pixel, inout vec3 light, inout vec3 normal, inout vec3 diffuse, inout vec3 emit){
    
     // shoot a ray out into the world
        raymarch(pos,dir,normal,diffuse,emit);
         
        // if the ray missed, we are done
        if (isSky){
            //add the sky color to the pixel
            vec3 skyColor=SRGBToLinear(skyTex(dir));
    
            pixel+=light*skyColor;
        }
   
        // add in emissive lighting
        pixel += emit *light;
        //pixel+=dat.diffuse;
         
        // update the colorMultiplier
    //light+=dat.emit;
        light *= diffuse; 
    
}



//given a position and local data there, find the new marching direction
void newBounceSetup(inout vec3 pos,inout vec3 dir, inout vec3 pixel, inout vec3 light, inout vec3 normal, inout vec3 diffuse, inout vec3 emit, uint rngState){
    vec3 newDir;
    // push a bit off the surface
       pos+=0.01*normal;
         
        // calculate new ray direction, in a cosine weighted hemisphere oriented at normal
        newDir = normalize(normal + RandomUnitVector(rngState));
        
        //update the tangent vector:
        dir=newDir;
}




vec3 pathTrace(inout vec3 pos,inout vec3 dir, inout vec3 pixel, inout vec3 light, inout vec3 normal, inout vec3 diffuse, inout vec3 emit, uint rngState){
    
    localData dat;
    int maxBounces=3;
    
    
        for (int bounceIndex = 0; bounceIndex <maxBounces; ++bounceIndex)
    {
            //march to the next surface, pick up light contributions
            stepForward(pos,dir,pixel,light,normal,diffuse,emit);
            if(isSky){break;}
            
            //set up the new direction to go in
            newBounceSetup(pos,dir,pixel,light,normal,diffuse,emit,rngState);
        }

    
    return pixel;
}











vec3 initializeRay(vec2 fragCoord){
    
    // The ray starts at the camera position (the origin)
    vec3 rayPosition = vec3(0.0f, 0.0f, 0.0f);
    
     // calculate coordinates of the ray target on the imaginary pixel plane.
    vec2 planeCoords=(fragCoord/iResolution.xy) * 2.0f - 1.0f;
         // correct for aspect ratio
    float aspectRatio = iResolution.x / iResolution.y;
    planeCoords.y /= aspectRatio;
    
    //move z-distance for fov:
    float z=-1./ tan(radians(fov * 0.5));
    
    // -1 to +1 on x,y axis. 1 unit away on the z axis
    vec3 rayTarget = vec3(planeCoords, z);
     

    // calculate a normalized vector for the ray direction.
    // it's pointing from the ray position to the ray target.
    vec3 rayDir = normalize(rayTarget);
    
return rayDir;
    
}










void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
   
    // initialize a random number state based on frag coord and frame
uint rngState = uint(uint(fragCoord.x) * uint(1973) + uint(fragCoord.y) * uint(9277) + uint(iFrame) * uint(26699)) | uint(1);
    
    vec3 normal, diffuse, emit;
    
    //get the initial tangent vector, path data
    vec3 pos=vec3(0,0,0);
    vec3 dir=initializeRay(fragCoord);
    vec3 pixel=vec3(0.);
    vec3 light=vec3(1.);
    
    
    //do one trace out into the scene
    vec3 color=pathTrace(pos,dir,pixel,light,normal, diffuse, emit,rngState);
    
    
    
    // add the frames together
    
    float weight=1./(iFrame+1.);
    
    vec3 prevFrames = texture(acc, fragCoord / iResolution.xy).rgb;
    
    color=iFrame*prevFrames+color;
    
    color=color/(iFrame+1.);
    
    
    
    
    fragColor = vec4(color, 1.0f);
}
























  void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
  }