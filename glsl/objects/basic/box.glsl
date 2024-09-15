

//-------------------------------------------------
//The BOX sdf
//-------------------------------------------------

//the data of a sphere is its center and radius
struct Box{
    vec3 center;
    vec3 sides;
    float rounded;
    Material mat;
};


//overload of distR3: distance in R3 coordinates
float distR3( vec3 p, Box box ){
    //normalize position
    vec3 pos = p - box.center;

    vec3 q = abs(pos) - box.sides;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - box.rounded;
}

//overload of location booleans:
bvec2 relPosition( Vector tv, Box box){

    float d = distR3( tv.pos, box );
    bool atSurf = ((abs(d) - AT_THRESH)<0.);
    bool inside = d<0.;
    return bvec2(atSurf, inside);
}

//overload of location booleans:
bool at( Vector tv,Box box){

    float d = distR3( tv.pos, box );
    bool atSurf = ((abs(d) - AT_THRESH)<0.);
    return atSurf;
}

bool inside( Vector tv, Box box ){
    float d = distR3( tv.pos, box );
    return (d<0.);
}




//overload of sdf for a sphere
float sdf( Vector tv, Box box ){

    //distance to closest point on box
    float d=distR3(tv.pos, box);
    return d;
}


//overload of normalVec for a sphere
Vector normalVec( Vector tv, Box box ){

    vec3 pos=tv.pos;

    const float ep = 0.0001;
    vec2 e = vec2(1.0,-1.0)*0.5773;

    float vxyy=distR3( pos + e.xyy*ep, box);
    float vyyx=distR3( pos + e.yyx*ep, box);
    float vyxy=distR3( pos + e.yxy*ep, box);
    float vxxx=distR3( pos + e.xxx*ep, box);

    vec3 dir=  e.xyy*vxyy + e.yyx*vyyx + e.yxy*vyxy + e.xxx*vxxx;

    dir=normalize(dir);

    return Vector(tv.pos,dir);

}



//overload of setData for a sphere
void setData( inout Path path, Box box){

    //if we are at the surface
    if(at(path.tv, box)){
        //compute the normal
        Vector normal=normalVec(path.tv,box);
        bool side = inside(path.tv, box);
        //set the material
        setObjectInAir(path.dat, side, normal, box.mat);
    }

}





