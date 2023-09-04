//-------------------------------------------------
// ALGEBRAIC VARIETIES
// a Variety is raymarched with distance estimation
// these are "basic objects" that can be used to build more complex ones
//-------------------------------------------------
//redefining T so this file doesnt get mad --------------------------------------
#define T vec2


//--- The Distance Estimator -----
// Takes in a value and gradient length, approximated distance to zero level set:

float DE(float val, float gradLength){

    float k = 1.-1./(abs(val)+1.);
    float param = 3.0; // a free parameter we can set to change accuracy/speed (trial and error)
    float adjustedSpeed = gradLength+param*k+.001;

    float dist = val/adjustedSpeed;
    return 0.5*dist;
}


//----------------------------------------------------------------------------------------------
// Dual - Number Formulas for various varieties:
//----------------------------------------------------------------------------------------------------

T gyroid(T x, T y, T z){
    T term1 = tmul(tsin(x),cos(y));
    T term2 = tmul(tsin(y), tcos(z));
    T term3 = tmul(tsin(z),tcos(x));
    return term1 + term2 + term3;
}

T barthSextic(T x, T y, T z){
    T x2 = tsqr(x);
    T y2 = tsqr(y);
    T z2 = tsqr(z);
    float phi1=(1.+sqrt(5.))/2., phi2=phi1*phi1;

    T term1 = 4.*tmul(phi2*x2-y2, phi2*y2-z2, phi2*z2-x2);
    T term2 = (1.+2.*phi1) * tmul(x2+y2+z2-T(1,0),x2+y2+z2-T(1,0));

    return -(term1-term2);
}

T chmutov(T x, T y, T z) {
    int n = 4;
    return tcheb(x,n)+tcheb(y,n)+tcheb(z,n)+tfloat(1.0);
}







//----------------------------------------------------------------------------------------------
// ADJUSTABLE VARIETY:
// ALL THAT NEEDS TO BE CHANGED IS THE FUNCTION SURF: THE REST AUTOMATICALLY UPDATES FROM THIS
//----------------------------------------------------------------------------------------------------

T surf(T x, T y, T z){
    return barthSextic(x,y,z);
}

vec4 surf_Data( vec3 p ){

    //Compute gradient.
    T vx = surf( T(p.x, 1.), T(p.y, 0.), T(p.z, 0.) );
    T vy = surf( T(p.x, 0.), T(p.y, 1.), T(p.z, 0.) );
    T vz = surf( T(p.x, 0.), T(p.y, 0.), T(p.z, 1.) );
    vec3 grad = vec3(vx.y,vy.y,vz.y);

    //the value of the function is automatically computed in each of the above:
    float val = vx.x;

    return vec4(grad,val);
}


//-------------------------------------------------
// my stuff: building the sextic in our world
// -------------------------

struct Variety{
    vec3 center;
    float size;
    float inside;
    float outside;
    float boundingSphere;
    float smoothing;
    Material mat;
};


//overload of distR3: distance in R3 coordinates
float distR3( vec3 p, Variety surf ){

    //normalize position
    vec3 pos = p - surf.center;
    float rad = length(pos);
    pos *= surf.size;

    //get the distance estimate
    vec4 data = surf_Data(pos);
    float val = data.w;
    float gradLength = length(data.xyz);
    float dist = DE(val, gradLength);

    //adjust to account for thickness of surface
    dist=abs(dist+surf.inside)-surf.inside-surf.outside;
    //adjust for the bounding box
    dist = smax(dist,rad-surf.boundingSphere,surf.smoothing);

    return dist;
}

//overload of location booleans:
bool at( Vector tv, Variety surf){
    float d = distR3( tv.pos, surf );
    bool atSurf = ((abs(d) - AT_THRESH)<0.);
    return atSurf;
}

bool inside( Vector tv, Variety surf ){
    float d = distR3( tv.pos, surf );
    return (d<0.);
}

//overload of sdf for a sphere
float sdf( Vector tv, Variety surf ){
    //distance to closest point on sphere
    return distR3(tv.pos, surf);
}

//overload of normalVec for a sphere
Vector normalVec( Vector tv, Variety surf ){

    //    vec3 pos=tv.pos;
    //    vec4 data = surf_Data(pos);
    //    vec3 grad = data.xyz;
    //    vec3 normal = normalize(grad);
    //    return Vector(pos,normal);


    //    vec3 grad = BarthGrad(pos);
    //    vec3 normal = normalize(grad);
    //    return Vector(pos,normal);

    vec3 pos =tv.pos;
    const float ep = 0.0001;
    vec2 e = vec2(1.0,-1.0)*0.5773;//this normalization makes exyy etc all unit vectors;

    float vxyy=distR3( pos + e.xyy*ep, surf);
    float vyyx=distR3( pos + e.yyx*ep, surf);
    float vyxy=distR3( pos + e.yxy*ep, surf);
    float vxxx=distR3( pos + e.xxx*ep, surf);

    vec3 dir=  e.xyy*vxyy + e.yyx*vyyx + e.yxy*vyxy + e.xxx*vxxx;

    dir=normalize(dir);

    return Vector(tv.pos,dir);

}

//overload of setData for a sphere
void setData( inout Path path, Variety surf ){

    //if we are at the surface
    if(at(path.tv, surf)){
        //compute the normal
        Vector normal=normalVec(path.tv,surf);
        bool side = inside(path.tv, surf);
        //set the material
        setObjectInAir(path.dat, side, normal, surf.mat);
    }

}
