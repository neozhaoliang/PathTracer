 #include <common>

uniform vec3 iResolution;
uniform float iTime;
uniform sampler2D sky;
uniform sampler2D acc;
uniform float iFrame;







vec2 toSphCoords(vec3 v){
float theta=atan(v.z,v.x);
float phi=acos(v.y);
return vec2(theta,phi);
}




vec3 skyTex(vec3 v){

vec2 angles=toSphCoords(v);
float x=(angles.x+3.1415)/(2.*3.1415);
float y=1.-angles.y/3.1415;

return texture(sky,vec2(x,y)).rgb;

}




const float c_pi = 3.14159265359f;
const float c_twopi = 2.0f * c_pi;

const float KEY_SPACE = 32.5/256.0;

// The minimunm distance a ray must travel before we consider an intersection.
// This is to prevent a ray from intersecting a surface it just bounced off of.
const float c_minimumRayHitTime = 0.01f;

// after a hit, it moves the ray this far along the normal away from a surface.
// Helps prevent incorrect intersections when rays bounce off of objects.
const float c_rayPosNormalNudge = 0.01f;

// the farthest we look for ray hits
const float c_superFar = 10000.0f;

// camera FOV
const float c_FOVDegrees = 90.0f;

// number of ray bounces allowed max
const int c_numBounces = 8;

// a multiplier for the skybox brightness
const float c_skyboxBrightnessMultiplier = 1.0f;
    
// a pixel value multiplier of light before tone mapping and sRGB
const float c_exposure = 1.0f; 

// how many renders per frame - make this larger to get around the vsync limitation, and get a better image faster.
const int c_numRendersPerFrame = 7;

// mouse camera control parameters
const float c_minCameraAngle = 0.01f;
const float c_maxCameraAngle = (c_pi - 0.01f);
const vec3 c_cameraAt = vec3(0.0f, 0.0f, 0.0f);
const float c_cameraDistance = 30.0f;

// 0 = transparent orange spheres of increasing surface roughness
// 1 = transparent spheres of increasing IOR
// 2 = opaque spheres of increasing IOR
// 3 = transparent spheres of increasing absorption
// 4 = transparent spheres of various heights, to show hot spot focus/defocus
// 5 = transparent spheres becoming increasingly diffuse
// 6 = transparent spheres of increasing surface roughness
#define SCENE 3

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

// ACES tone mapping curve fit to go from HDR to LDR
//https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
vec3 ACESFilm(vec3 x)
{
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return clamp((x*(a*x + b)) / (x*(c*x + d) + e), 0.0f, 1.0f);
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
    float a = RandomFloat01(state) * c_twopi;
    float r = sqrt(1.0f - z * z);
    float x = r * cos(a);
    float y = r * sin(a);
    return vec3(x, y, z);
}

struct SMaterialInfo
{
    // Note: diffuse chance is 1.0f - (specularChance+refractionChance)
    vec3  albedo;              // the color used for diffuse lighting
    vec3  emissive;            // how much the surface glows
    float specularChance;      // percentage chance of doing a specular reflection
    float specularRoughness;   // how rough the specular reflections are
    vec3  specularColor;       // the color tint of specular reflections
    float IOR;                 // index of refraction. used by fresnel and refraction.
    float refractionChance;    // percent chance of doing a refractive transmission
    float refractionRoughness; // how rough the refractive transmissions are
    vec3  refractionColor;     // absorption for beer's law    
};
    
SMaterialInfo GetZeroedMaterial()
{
    SMaterialInfo ret;
    ret.albedo = vec3(0.0f, 0.0f, 0.0f);
    ret.emissive = vec3(0.0f, 0.0f, 0.0f);
    ret.specularChance = 0.0f;
    ret.specularRoughness = 0.0f;
    ret.specularColor = vec3(0.0f, 0.0f, 0.0f);
    ret.IOR = 1.0f;
    ret.refractionChance = 0.0f;
    ret.refractionRoughness = 0.0f;
    ret.refractionColor = vec3(0.0f, 0.0f, 0.0f);
    return ret;
}

struct SRayHitInfo
{
    bool fromInside;
    float dist;
    vec3 normal;
    SMaterialInfo material;
};

float ScalarTriple(vec3 u, vec3 v, vec3 w)
{
    return dot(cross(u, v), w);
}

bool TestQuadTrace(in vec3 rayPos, in vec3 rayDir, inout SRayHitInfo info, in vec3 a, in vec3 b, in vec3 c, in vec3 d)
{
    // calculate normal and flip vertices order if needed
    vec3 normal = normalize(cross(c-a, c-b));
    if (dot(normal, rayDir) > 0.0f)
    {
        normal *= -1.0f;
        
		vec3 temp = d;
        d = a;
        a = temp;
        
        temp = b;
        b = c;
        c = temp;
    }
    
    vec3 p = rayPos;
    vec3 q = rayPos + rayDir;
    vec3 pq = q - p;
    vec3 pa = a - p;
    vec3 pb = b - p;
    vec3 pc = c - p;
    
    // determine which triangle to test against by testing against diagonal first
    vec3 m = cross(pc, pq);
    float v = dot(pa, m);
    vec3 intersectPos;
    if (v >= 0.0f)
    {
        // test against triangle a,b,c
        float u = -dot(pb, m);
        if (u < 0.0f) return false;
        float w = ScalarTriple(pq, pb, pa);
        if (w < 0.0f) return false;
        float denom = 1.0f / (u+v+w);
        u*=denom;
        v*=denom;
        w*=denom;
        intersectPos = u*a+v*b+w*c;
    }
    else
    {
        vec3 pd = d - p;
        float u = dot(pd, m);
        if (u < 0.0f) return false;
        float w = ScalarTriple(pq, pa, pd);
        if (w < 0.0f) return false;
        v = -v;
        float denom = 1.0f / (u+v+w);
        u*=denom;
        v*=denom;
        w*=denom;
        intersectPos = u*a+v*d+w*c;
    }
    
    float dist;
    if (abs(rayDir.x) > 0.1f)
    {
        dist = (intersectPos.x - rayPos.x) / rayDir.x;
    }
    else if (abs(rayDir.y) > 0.1f)
    {
        dist = (intersectPos.y - rayPos.y) / rayDir.y;
    }
    else
    {
        dist = (intersectPos.z - rayPos.z) / rayDir.z;
    }
    
	if (dist > c_minimumRayHitTime && dist < info.dist)
    {
        info.fromInside = false;
        info.dist = dist;        
        info.normal = normal;        
        return true;
    }    
    
    return false;
}

float FresnelReflectAmount(float n1, float n2, vec3 normal, vec3 incident, float f0, float f90)
{
        // Schlick aproximation
        float r0 = (n1-n2) / (n1+n2);
        r0 *= r0;
        float cosX = -dot(normal, incident);
        if (n1 > n2)
        {
            float n = n1/n2;
            float sinT2 = n*n*(1.0-cosX*cosX);
            // Total internal reflection
            if (sinT2 > 1.0)
                return f90;
            cosX = sqrt(1.0-sinT2);
        }
        float x = 1.0-cosX;
        float ret = r0+(1.0-r0)*x*x*x*x*x;

        // adjust reflect multiplier for object reflectivity
        return mix(f0, f90, ret);
}

bool TestSphereTrace(in vec3 rayPos, in vec3 rayDir, inout SRayHitInfo info, in vec4 sphere)
{    
	//get the vector from the center of this sphere to where the ray begins.
	vec3 m = rayPos - sphere.xyz;

    //get the dot product of the above vector and the ray's vector
	float b = dot(m, rayDir);

	float c = dot(m, m) - sphere.w * sphere.w;

	//exit if r's origin outside s (c > 0) and r pointing away from s (b > 0)
	if(c > 0.0 && b > 0.0)
		return false;

	//calculate discriminant
	float discr = b * b - c;

	//a negative discriminant corresponds to ray missing sphere
	if(discr < 0.0)
		return false;
    
	//ray now found to intersect sphere, compute smallest t value of intersection
    bool fromInside = false;
	float dist = -b - sqrt(discr);
    if (dist < 0.0f)
    {
        fromInside = true;
        dist = -b + sqrt(discr);
    }
    
	if (dist > c_minimumRayHitTime && dist < info.dist)
    {
        info.fromInside = fromInside;
        info.dist = dist;        
        info.normal = normalize((rayPos+rayDir*dist) - sphere.xyz) * (fromInside ? -1.0f : 1.0f);
        return true;
    }
    
    return false;
}

void TestSceneTrace(in vec3 rayPos, in vec3 rayDir, inout SRayHitInfo hitInfo)
{
    // floor
    {
        vec3 A = vec3(-25.0f, -12.5f, 5.0f);
        vec3 B = vec3( 25.0f, -12.5f, 5.0f);
        vec3 C = vec3( 25.0f, -12.5f, -5.0f);
        vec3 D = vec3(-25.0f, -12.5f, -5.0f);
        if (TestQuadTrace(rayPos, rayDir, hitInfo, A, B, C, D))
        {
            hitInfo.material = GetZeroedMaterial();
            hitInfo.material.albedo = vec3(0.7f, 0.7f, 0.7f);         
        }        
    }
    
    // striped background
    {
        vec3 A = vec3(-25.0f, -1.5f, 5.0f);
        vec3 B = vec3( 25.0f, -1.5f, 5.0f);
        vec3 C = vec3( 25.0f, -10.5f, 5.0f);
        vec3 D = vec3(-25.0f, -10.5f, 5.0f);
        if (TestQuadTrace(rayPos, rayDir, hitInfo, A, B, C, D))
        {
            hitInfo.material = GetZeroedMaterial();
            
            vec3 hitPos = rayPos + rayDir * hitInfo.dist;
            
            float shade = floor(mod(hitPos.x, 1.0f) * 2.0f);
            hitInfo.material.albedo = vec3(shade, shade, shade);
        }        
    }
    
    // cieling piece above light
    {
        vec3 A = vec3(-7.5f, 12.5f, 5.0f);
        vec3 B = vec3( 7.5f, 12.5f, 5.0f);
        vec3 C = vec3( 7.5f, 12.5f, -5.0f);
        vec3 D = vec3(-7.5f, 12.5f, -5.0f);
        if (TestQuadTrace(rayPos, rayDir, hitInfo, A, B, C, D))
        {
            hitInfo.material = GetZeroedMaterial();
            hitInfo.material.albedo = vec3(0.7f, 0.7f, 0.7f);
        }        
    }    
    
    // light
    {
        vec3 A = vec3(-5.0f, 12.4f,  2.5f);
        vec3 B = vec3( 5.0f, 12.4f,  2.5f);
        vec3 C = vec3( 5.0f, 12.4f,  -2.5f);
        vec3 D = vec3(-5.0f, 12.4f,  -2.5f);
        if (TestQuadTrace(rayPos, rayDir, hitInfo, A, B, C, D))
        {
            hitInfo.material = GetZeroedMaterial();
            hitInfo.material.emissive = vec3(1.0f, 0.9f, 0.7f) * 20.0f;   
        }        
    }    
    
#if SCENE == 0
    
    const int c_numSpheres = 7;
    for (int sphereIndex = 0; sphereIndex < c_numSpheres; ++sphereIndex)
    {
		if (TestSphereTrace(rayPos, rayDir, hitInfo, vec4(-18.0f + 6.0f * float(sphereIndex), -8.0f, 00.0f, 2.8f)))
        {
            float r = float(sphereIndex) / float(c_numSpheres-1) * 0.5f;
            
            hitInfo.material = GetZeroedMaterial();
            hitInfo.material.albedo = vec3(0.9f, 0.25f, 0.25f);
            hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);        
            hitInfo.material.specularChance = 0.02f;
            hitInfo.material.specularRoughness = r;
            hitInfo.material.specularColor = vec3(1.0f, 1.0f, 1.0f) * 0.8f;
            hitInfo.material.IOR = 1.1f;
            hitInfo.material.refractionChance = 1.0f;
            hitInfo.material.refractionRoughness = r;
            hitInfo.material.refractionColor = vec3(0.0f, 0.5f, 1.0f);
    	} 
    }
    
#elif SCENE == 1

	const int c_numSpheres = 7;
    for (int sphereIndex = 0; sphereIndex < c_numSpheres; ++sphereIndex)
    {
		if (TestSphereTrace(rayPos, rayDir, hitInfo, vec4(-18.0f + 6.0f * float(sphereIndex), -8.0f, 0.0f, 2.8f)))
        {
            float ior = 1.0f + 0.5f * float(sphereIndex) / float(c_numSpheres-1);
            
            hitInfo.material = GetZeroedMaterial();
            hitInfo.material.albedo = vec3(0.9f, 0.25f, 0.25f);
            hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);        
            hitInfo.material.specularChance = 0.02f;
            hitInfo.material.specularRoughness = 0.0f;
            hitInfo.material.specularColor = vec3(1.0f, 1.0f, 1.0f) * 0.8f;
            hitInfo.material.IOR = ior;
            hitInfo.material.refractionChance = 1.0f;
            hitInfo.material.refractionRoughness = 0.0f;
    	} 
    }
    
#elif SCENE == 2

	const int c_numSpheres = 7;
    for (int sphereIndex = 0; sphereIndex < c_numSpheres; ++sphereIndex)
    {
		if (TestSphereTrace(rayPos, rayDir, hitInfo, vec4(-18.0f + 6.0f * float(sphereIndex), -8.0f, 0.0f, 2.8f)))
        {
            float ior = 1.0f + 1.0f * float(sphereIndex) / float(c_numSpheres-1);
            
            hitInfo.material = GetZeroedMaterial();
            hitInfo.material.albedo = vec3(0.9f, 0.25f, 0.25f);
            hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);        
            hitInfo.material.specularChance = 0.02f;
            hitInfo.material.specularRoughness = 0.0f;
            hitInfo.material.specularColor = vec3(1.0f, 1.0f, 1.0f) * 0.8f;
            hitInfo.material.IOR = ior;
            hitInfo.material.refractionChance = 0.0f;
    	} 
    }  
    
#elif SCENE == 3

	const int c_numSpheres = 7;
    for (int sphereIndex = 0; sphereIndex < c_numSpheres; ++sphereIndex)
    {
		if (TestSphereTrace(rayPos, rayDir, hitInfo, vec4(-18.0f + 6.0f * float(sphereIndex), -8.0f, 0.0f, 2.8f)))
        {
            float absorb = float(sphereIndex) / float(c_numSpheres-1);
            
            hitInfo.material = GetZeroedMaterial();
            hitInfo.material.albedo = vec3(0.9f, 0.25f, 0.25f);
            hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);        
            hitInfo.material.specularChance = 0.02f;
            hitInfo.material.specularRoughness = 0.0f;
            hitInfo.material.specularColor = vec3(1.0f, 1.0f, 1.0f) * 0.8f;
            hitInfo.material.IOR = 1.1f;
            hitInfo.material.refractionChance = 1.0f;
            hitInfo.material.refractionRoughness = 0.0f;
            hitInfo.material.refractionColor = vec3(1.0f, 2.0f, 3.0f) * absorb;
    	} 
    }    
    
#elif SCENE == 4

	const int c_numSpheres = 7;
    for (int sphereIndex = 0; sphereIndex < c_numSpheres; ++sphereIndex)
    {
		if (TestSphereTrace(rayPos, rayDir, hitInfo, vec4(-18.0f + 6.0f * float(sphereIndex), -9.0f + 0.75f * float(sphereIndex), 0.0f, 2.8f)))
        {            
            hitInfo.material = GetZeroedMaterial();
            hitInfo.material.albedo = vec3(0.9f, 0.25f, 0.25f);
            hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);        
            hitInfo.material.specularChance = 0.02f;
            hitInfo.material.specularRoughness = 0.0f;
            hitInfo.material.specularColor = vec3(1.0f, 1.0f, 1.0f) * 0.8f;
            hitInfo.material.IOR = 1.5f;
            hitInfo.material.refractionChance = 1.0f;
            hitInfo.material.refractionRoughness = 0.0f;
    	} 
    }      
    
#elif SCENE == 5
    
	const int c_numSpheres = 7;
    for (int sphereIndex = 0; sphereIndex < c_numSpheres; ++sphereIndex)
    {
		if (TestSphereTrace(rayPos, rayDir, hitInfo, vec4(-18.0f + 6.0f * float(sphereIndex), -9.0f, 0.0f, 2.8f)))
        {
            float transparency = float(sphereIndex) / float(c_numSpheres-1);
            
            hitInfo.material = GetZeroedMaterial();
            hitInfo.material.albedo = vec3(0.9f, 0.25f, 0.25f);
            hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);        
            hitInfo.material.specularChance = 0.02f;
            hitInfo.material.specularRoughness = 0.0f;
            hitInfo.material.specularColor = vec3(1.0f, 1.0f, 1.0f) * 0.8f;
            hitInfo.material.IOR = 1.1f;
            hitInfo.material.refractionChance = 1.0f - transparency;
            hitInfo.material.refractionRoughness = 0.0f;
    	} 
    }        
    
#elif SCENE == 6
    
    const int c_numSpheres = 7;
    for (int sphereIndex = 0; sphereIndex < c_numSpheres; ++sphereIndex)
    {
		if (TestSphereTrace(rayPos, rayDir, hitInfo, vec4(-18.0f + 6.0f * float(sphereIndex), -8.0f, 00.0f, 2.8f)))
        {
            float r = float(sphereIndex) / float(c_numSpheres-1) * 0.5f;
            
            hitInfo.material = GetZeroedMaterial();
            hitInfo.material.albedo = vec3(0.9f, 0.25f, 0.25f);
            hitInfo.material.emissive = vec3(0.0f, 0.0f, 0.0f);        
            hitInfo.material.specularChance = 0.02f;
            hitInfo.material.specularRoughness = r;
            hitInfo.material.specularColor = vec3(1.0f, 1.0f, 1.0f) * 0.8f;
            hitInfo.material.IOR = 1.1f;
            hitInfo.material.refractionChance = 1.0f;
            hitInfo.material.refractionRoughness = r;
            hitInfo.material.refractionColor = vec3(0.0f, 0.0f, 0.0f);
    	} 
    }    
    
#endif
}

vec3 GetColorForRay(in vec3 startRayPos, in vec3 startRayDir, inout uint rngState)
{
    // initialize
    vec3 ret = vec3(0.0f, 0.0f, 0.0f);
    vec3 throughput = vec3(1.0f, 1.0f, 1.0f);
    vec3 rayPos = startRayPos;
    vec3 rayDir = startRayDir;
    
    for (int bounceIndex = 0; bounceIndex <= c_numBounces; ++bounceIndex)
    {
        // shoot a ray out into the world
        SRayHitInfo hitInfo;
        hitInfo.material = GetZeroedMaterial();
        hitInfo.dist = c_superFar;
        hitInfo.fromInside = false;
        TestSceneTrace(rayPos, rayDir, hitInfo);
        
        // if the ray missed, we are done
        if (hitInfo.dist == c_superFar)
        {
            ret += SRGBToLinear(skyTex(rayDir)) * c_skyboxBrightnessMultiplier * throughput;
            break;
        }
        
        // do absorption if we are hitting from inside the object
        if (hitInfo.fromInside)
            throughput *= exp(-hitInfo.material.refractionColor * hitInfo.dist);
        
        // get the pre-fresnel chances
        float specularChance = hitInfo.material.specularChance;
        float refractionChance = hitInfo.material.refractionChance;
        //float diffuseChance = max(0.0f, 1.0f - (refractionChance + specularChance));
        
        // take fresnel into account for specularChance and adjust other chances.
        // specular takes priority.
        // chanceMultiplier makes sure we keep diffuse / refraction ratio the same.
        float rayProbability = 1.0f;
        if (specularChance > 0.0f)
        {
        	specularChance = FresnelReflectAmount(
            	hitInfo.fromInside ? hitInfo.material.IOR : 1.0,
            	!hitInfo.fromInside ? hitInfo.material.IOR : 1.0,
            	rayDir, hitInfo.normal, hitInfo.material.specularChance, 1.0f);
            
            float chanceMultiplier = (1.0f - specularChance) / (1.0f - hitInfo.material.specularChance);
            refractionChance *= chanceMultiplier;
            //diffuseChance *= chanceMultiplier;
        }
        
        // calculate whether we are going to do a diffuse, specular, or refractive ray
        float doSpecular = 0.0f;
        float doRefraction = 0.0f;
        float raySelectRoll = RandomFloat01(rngState);
		if (specularChance > 0.0f && raySelectRoll < specularChance)
        {
            doSpecular = 1.0f;
            rayProbability = specularChance;
        }
        else if (refractionChance > 0.0f && raySelectRoll < specularChance + refractionChance)
        {
            doRefraction = 1.0f;
            rayProbability = refractionChance;
        }
        else
        {
            rayProbability = 1.0f - (specularChance + refractionChance);
        }
        
        // numerical problems can cause rayProbability to become small enough to cause a divide by zero.
		rayProbability = max(rayProbability, 0.001f);
        
        // update the ray position
        if (doRefraction == 1.0f)
        {
            rayPos = (rayPos + rayDir * hitInfo.dist) - hitInfo.normal * c_rayPosNormalNudge;
        }
        else
        {
            rayPos = (rayPos + rayDir * hitInfo.dist) + hitInfo.normal * c_rayPosNormalNudge;
        }
         
        // Calculate a new ray direction.
        // Diffuse uses a normal oriented cosine weighted hemisphere sample.
        // Perfectly smooth specular uses the reflection ray.
        // Rough (glossy) specular lerps from the smooth specular to the rough diffuse by the material roughness squared
        // Squaring the roughness is just a convention to make roughness feel more linear perceptually.
        vec3 diffuseRayDir = normalize(hitInfo.normal + RandomUnitVector(rngState));
        
        vec3 specularRayDir = reflect(rayDir, hitInfo.normal);
        specularRayDir = normalize(mix(specularRayDir, diffuseRayDir, hitInfo.material.specularRoughness*hitInfo.material.specularRoughness));

        vec3 refractionRayDir = refract(rayDir, hitInfo.normal, hitInfo.fromInside ? hitInfo.material.IOR : 1.0f / hitInfo.material.IOR);
        refractionRayDir = normalize(mix(refractionRayDir, normalize(-hitInfo.normal + RandomUnitVector(rngState)), hitInfo.material.refractionRoughness*hitInfo.material.refractionRoughness));
                
        rayDir = mix(diffuseRayDir, specularRayDir, doSpecular);
        rayDir = mix(rayDir, refractionRayDir, doRefraction);
        
		// add in emissive lighting
        ret += hitInfo.material.emissive * throughput;
        
        // update the colorMultiplier. refraction doesn't alter the color until we hit the next thing, so we can do light absorption over distance.
        if (doRefraction == 0.0f)
        	throughput *= mix(hitInfo.material.albedo, hitInfo.material.specularColor, doSpecular);
        
        // since we chose randomly between diffuse, specular, refract,
        // we need to account for the times we didn't do one or the other.
        throughput /= rayProbability;
        
        // Russian Roulette
        // As the throughput gets smaller, the ray is more likely to get terminated early.
        // Survivors have their value boosted to make up for fewer samples being in the average.
        {
        	float p = max(throughput.r, max(throughput.g, throughput.b));
        	if (RandomFloat01(rngState) > p)
            	break;

        	// Add the energy we 'lose' by randomly terminating paths
        	throughput *= 1.0f / p;            
        }
    }
 
    // return pixel color
    return ret;
}

void GetCameraVectors(out vec3 cameraPos, out vec3 cameraFwd, out vec3 cameraUp, out vec3 cameraRight)
{
    // if the mouse is at (0,0) it hasn't been moved yet, so use a default camera setup
//    vec2 mouse = iMouse.xy;
//    if (dot(mouse, vec2(1.0f, 1.0f)) == 0.0f)
//    {
        cameraPos = vec3(0.0f, 0.0f, -c_cameraDistance);
        cameraFwd = vec3(0.0f, 0.0f, 1.0f);
        cameraUp = vec3(0.0f, 1.0f, 0.0f);
        cameraRight = vec3(1.0f, 0.0f, 0.0f);
        return;
//    }
    
    // otherwise use the mouse position to calculate camera position and orientation
    
//    float angleX = -mouse.x * 16.0f / float(iResolution.x);
//    float angleY = mix(c_minCameraAngle, c_maxCameraAngle, mouse.y / float(iResolution.y));
//    
//    cameraPos.x = sin(angleX) * sin(angleY) * c_cameraDistance;
//    cameraPos.y = -cos(angleY) * c_cameraDistance;
//    cameraPos.z = cos(angleX) * sin(angleY) * c_cameraDistance;
//    
//    cameraPos += c_cameraAt;
//    
//    cameraFwd = normalize(c_cameraAt - cameraPos);
//    cameraRight = normalize(cross(vec3(0.0f, 1.0f, 0.0f), cameraFwd));
//    cameraUp = normalize(cross(cameraFwd, cameraRight));   
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // initialize a random number state based on frag coord and frame
    uint rngState = uint(uint(fragCoord.x) * uint(1973) + uint(fragCoord.y) * uint(9277) + uint(iFrame) * uint(26699)) | uint(1);    
    
    // calculate subpixel camera jitter for anti aliasing
    vec2 jitter = vec2(RandomFloat01(rngState), RandomFloat01(rngState)) - 0.5f;

    // get the camera vectors
    vec3 cameraPos, cameraFwd, cameraUp, cameraRight;
    GetCameraVectors(cameraPos, cameraFwd, cameraUp, cameraRight);    
    vec3 rayDir;
    {   
        // calculate a screen position from -1 to +1 on each axis
        vec2 uvJittered = (fragCoord+jitter)/iResolution.xy;
		vec2 screen = uvJittered * 2.0f - 1.0f;
        
        // adjust for aspect ratio
        float aspectRatio = iResolution.x / iResolution.y;
        screen.y /= aspectRatio;
                
        // make a ray direction based on camera orientation and field of view angle
        float cameraDistance = tan(c_FOVDegrees * 0.5f * c_pi / 180.0f);       
        rayDir = vec3(screen, cameraDistance);
        rayDir = normalize(mat3(cameraRight, cameraUp, cameraFwd) * rayDir);
    }
    
    // raytrace for this pixel
    vec3 color = vec3(0.0f, 0.0f, 0.0f);
    for (int index = 0; index < c_numRendersPerFrame; ++index)
    	color += GetColorForRay(cameraPos, rayDir, rngState) / float(c_numRendersPerFrame);




//    // add the frames together
    
    float weight=1./(iFrame+1.);
    
    
    vec3 prevFrames = texture(acc, fragCoord / iResolution.xy).rgb;
    
    color=iFrame*prevFrames+color;
    
    color=color/(iFrame+1.);
    
   // color=mix(prevFrames, color, weight);


    // show the result
    fragColor = vec4(color, 1.);
}




  void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
  }
