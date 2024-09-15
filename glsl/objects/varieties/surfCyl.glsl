
//----------------------------------------------------------------------------------------------
// ADJUSTABLE VARIETY:
// ALL THAT NEEDS TO BE CHANGED IS THE FUNCTION SURF: THE REST AUTOMATICALLY UPDATES FROM THIS
//----------------------------------------------------------------------------------------------------


vec4 surfCyl_Data( vec3 p ){

    //Compute gradient.
    T vx = surfCyl_Eqn( T(p.x, 1.), T(p.y, 0.), T(p.z, 0.) );
    T vy = surfCyl_Eqn( T(p.x, 0.), T(p.y, 1.), T(p.z, 0.) );
    T vz = surfCyl_Eqn( T(p.x, 0.), T(p.y, 0.), T(p.z, 1.) );
    vec3 grad = vec3(vx.y,vy.y,vz.y);

    //the value of the function is automatically computed in each of the above:
    float val = vx.x;

    return vec4(grad,val);
}



//-------------------------------------------------
// Building a variey that is infinitesimally thin
// -------------------------

struct SurfCyl{
    vec3 center;
    vec2 cyl;
    float scale;
    Material mat;
};


//dist to bounding box
float bCyl(vec3 pos, vec2 cyl){

    float r = length(pos.xz)-cyl.x;
    float h = abs(pos.y)-cyl.y;
    float bboxDist = max(r,h);

    return bboxDist;
}

//overload of distR3: distance in R3 coordinates
float distR3( vec3 p, SurfCyl surf ){

    //normalize position
    vec3 pos = p - surf.center;
    vec3 scaledPos = surf.scale * pos;

    //get the distance estimate
    vec4 data = surfCyl_Data(scaledPos);
    float val = data.w;
    float gradLength = length(data.xyz) * surf.scale;
    float dist = DE(val, gradLength);

    dist=abs(dist);

    //bounding sphere
    float bboxDist = bCyl(pos,surf.cyl);
    dist = max(dist,bboxDist);

    return dist;
}


//overload of distR3 and sdf
float distR3( Vector tv, SurfCyl surf ){
    float dist = distR3(tv.pos,surf);
    return dist;
}

float sdf( Vector tv, SurfCyl surf ){
    return distR3(tv.pos, surf);
}


//overload of location booleans:
bool at( Vector tv, SurfCyl surf){
    float d = distR3( tv.pos, surf );
    bool atSurf = ((abs(d) - AT_THRESH)<0.);
    return atSurf;
}

bool inside( Vector tv, SurfCyl surf ){
    float d = distR3( tv.pos, surf );
    return (d<0.);
}


Vector normalVec( Vector tv, SurfCyl surf ){

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

//setData for a two sided surface
void setData( inout Path path, SurfCyl surf ){

    //if we are at the surface
    if(at(path.tv, surf)){
        //compute the normal
        Vector normal=normalVec(path.tv,surf);
        Material mat=surf.mat;

        //check if we are on the outside edge:
        vec3 pos = path.tv.pos-surf.center;
        bool onEdge = abs(bCyl(pos,surf.cyl))<0.005;

        if(onEdge){
            //average of the two side colors
            mat.diffuseColor=0.5*(mat.diffuseColor + mat.diffuseColorBack);
            //set the material
            setObjectInAir(path.dat, false, normal, mat);
        }
        else {

            //what side of the variety are we on?
            vec3 pos = path.tv.pos - surf.center;
            pos *= surf.scale;
            float val= surfCyl_Data(pos).w;
            //val positive is one side, val negative is the other;

            if(val<0.){
                mat.diffuseColor=surf.mat.diffuseColorBack;
            }
            else{
                mat.diffuseColor=surf.mat.diffuseColor;
            }

            bool side = inside(path.tv, surf);
            setObjectInAir(path.dat, side, normal, mat);
        }
    }

}



