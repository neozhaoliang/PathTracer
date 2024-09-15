
//----------------------------------------------------------------------------------------------
// ADJUSTABLE VARIETY IN SPHERICAL BOUNDING BOX:
// before including this file need to provide TWO functions:
// T var_Eqn(T x, T y, T z)
// float var_bBox( vec3 pos )
//----------------------------------------------------------------------------------------------------


//use the variety equation to compute gradient and value
//for use in the raymarch
vec4 var_Data( vec3 p ){

    //Compute gradient.
    T vx = var_Eqn( T(p.x, 1.), T(p.y, 0.), T(p.z, 0.) );
    T vy = var_Eqn( T(p.x, 0.), T(p.y, 1.), T(p.z, 0.) );
    T vz = var_Eqn( T(p.x, 0.), T(p.y, 0.), T(p.z, 1.) );
    vec3 grad = vec3(vx.y,vy.y,vz.y);

    //the value of the function is automatically computed in each of the above:
    float val = vx.x;

    return vec4(grad,val);
}

//-------------------------------------------------
// Building a variety that is thick
// ------------------------------------------------

struct Variety{
    //the bounding sphere
    vec3 center;
    //smoothing between bounding box and variety
    float smoothing;
    //scale of the variety on the inside
    float scale;
    //thickness.x = inside thickness, thickness.y = outside thickness
    vec2 thickness;
    //the material
    Material mat;
};


//overload of distR3: distance in R3 coordinates
float distR3( vec3 p, Variety var ){

    //normalize position
    vec3 pos = p - var.center;
    vec3 scaledPos = var.scale * pos;

    //get the distance estimate
    vec4 data = var_Data(scaledPos);
    float val = data.w;
    float gradLength = length(data.xyz) * var.scale;
    float dist = DE(val, gradLength);

    //adjust to account for thickness of surface
    //thickness.x = inside, thickness.y = outisde
    dist=abs(dist+var.thickness.x)-var.thickness.x-var.thickness.y;

    // //bounding sphere
    float bboxDist = var_bBox(pos);

    //adjust for the bounding box
    dist = smax(dist,bboxDist,var.smoothing);

    //return dist;
    return dist;
}



float distR3( Vector tv, Variety var ){
    float dist = distR3(tv.pos,var);
    return dist;
}

//overload of location booleans:
bool at( Vector tv, Variety var){
    float d = distR3( tv.pos, var );
    bool atSurf = ((abs(d) - AT_THRESH)<0.);
    return atSurf;
}

bool inside( Vector tv, Variety var ){
    float d = distR3( tv.pos, var );
    return (d<0.);
}

//overload of sdf for a sphere
float sdf( Vector tv, Variety var ){
    //distance to closest point on sphere
    return distR3(tv.pos, var);
}

//overload of normalVec for a sphere
Vector normalVec( Vector tv, Variety var ){

    vec3 pos =tv.pos;
    const float ep = 0.0001;
    vec2 e = vec2(1.0,-1.0)*0.5773;//this normalization makes exyy etc all unit vectors;

    float vxyy=distR3( pos + e.xyy*ep, var);
    float vyyx=distR3( pos + e.yyx*ep, var);
    float vyxy=distR3( pos + e.yxy*ep, var);
    float vxxx=distR3( pos + e.xxx*ep, var);

    vec3 dir=  e.xyy*vxyy + e.yyx*vyyx + e.yxy*vyxy + e.xxx*vxxx;

    dir=normalize(dir);

    return Vector(tv.pos,dir);

}



//setData for a single sided, volume material
void setData( inout Path path, Variety var ){

    //if we are at the surface
    if(at(path.tv, var)){

        //compute the normal
        Vector normal = normalVec(path.tv,var);
        Material mat = var.mat;

        bool side = inside(path.tv, var);
        setObjectInAir(path.dat, side, normal, mat);
    }
}
