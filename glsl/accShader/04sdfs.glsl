
//-------------------------------------------------
//The SPHERE sdf
//-------------------------------------------------

//the data of a sphere is its center and radius
struct Sphere{
    Point center;
    float radius;
    Material mat;
};







float sphDist(vec3 pos,Sphere sph){

    return fakeDistance(Point(pos),sph.center)-sph.radius;
}


Vector sphereNormal(Vector tv, Sphere sph){
    
    const float ep = 0.0001;
    vec2 e = vec2(1.0,-1.0)*0.5773;
    
    //make matrix which translates observer to origin
    Isometry shift=makeInvLeftTranslation(tv.pos);
    
    //shift the sphere by this:
    sph.center=translate(shift,sph.center);
    
    //find the tangent vector
    vec3 dir=  e.xyy*sphDist( ORIGIN.coords+ e.xyy*ep,sph ) + 
					  e.yyx*sphDist( ORIGIN.coords + e.yyx*ep,sph) + 
					  e.yxy*sphDist( ORIGIN.coords + e.yxy*ep,sph) + 
					  e.xxx*sphDist( ORIGIN.coords + e.xxx*ep,sph);
    
    dir=normalize(dir);
    
    //make the output vector: original position + this tangent

    return Vector(tv.pos,dir);
}


float sphereSDF(Vector tv, Sphere sph,inout localData dat){
    
    //distance to closest point:
    float d = sphDist(tv.pos.coords,sph);
    

    if(d<EPSILON){//set the material
        dat.isSky=false;
        dat.normal=sphereNormal(tv,sph);
        dat.mat=sph.mat;
    }
    
    return d;
}









//-------------------------------------------------
//The PLANE sdf
//-------------------------------------------------

//the data of a plane is its normal and a constant:

struct EucPlane{
    float height;
    float sign;
    Material mat;
};


float EucPlaneDist(Point p,EucPlane plane){
    return plane.sign*(p.coords.z-plane.height);
}


Vector EucPlaneNormal(Vector tv,EucPlane plane){
    return Vector(tv.pos, plane.sign*vec3(0,0,1));
}


float EucPlaneSDF(Vector tv, EucPlane plane, inout localData dat){

    //otherwise give distance to closest point
    float d=EucPlaneDist(tv.pos,plane);
    
    if(d<EPSILON){//set the material
        dat.isSky=false;
        dat.normal=EucPlaneNormal(tv,plane);
        dat.mat=EucPlane.mat;
    }
    
    return d;
    
}













//
//
////-------------------------------------------------
//// The RING sdf
////-------------------------------------------------
//
//
////the data of a ring is its center, its radius, its tubeRadius, and the height elongation
//
//struct Ring{
//    vec3 center;
//    float radius;
//    float tubeRad;
//    float stretch;
//    Material mat;
//};
//
//
//float ringDist(vec3 pos, Ring ring){
//    
//     //recenter things
//    vec3 q = pos-ring.center;
//    //choose the direction of elongation
//    vec3 H=vec3(0,ring.stretch,0);
//    //stretch out the sdf
//    vec4 w=vec4(q-clamp(q,-H,H),0.);
//    //standard torus SDF
//    vec2 Q=vec2(length(w.xz)-ring.radius,w.y);
//    float d=length(Q)-ring.tubeRad;
//
//    return d;
//}
//
//
//
////probably a way to do this directly and not sample....
////should come back to this
//Vector ringNormal(Vector tv, Ring ring){
//    
//    //translate everything
//    vec3 pos=tv.pos-ring.center;
//    
//    //reset ring's center to zero:
//    ring.center=vec3(0.);
//    
//    const float ep = 0.0001;
//    vec2 e = vec2(1.0,-1.0)*0.5773;
//    
//    vec3 dir=  e.xyy*ringDist( pos + e.xyy*ep,ring ) + 
//					  e.yyx*ringDist( pos + e.yyx*ep,ring) + 
//					  e.yxy*ringDist( pos + e.yxy*ep,ring) + 
//					  e.xxx*ringDist( pos + e.xxx*ep,ring);
//    
//    dir=normalize(dir);
//    
//    return Vector(tv.pos,dir);
//}
//    
//
//
//
//
//
//float ringSDF(Vector tv, Ring ring,inout localData dat){
//
//
//    float d= ringDist(tv.pos,ring);
//    
//    //-----------------
//    
//    if(d<EPSILON){//set the material
//        dat.isSky=false;
//        dat.normal=ringNormal(tv,ring);
//        dat.mat=ring.mat;
//    }
//    
//    return d;
//}
//
//
//
//
//    
//




//-------------------------------------------------
// The LENS sdf
//-------------------------------------------------

//the data of a lens is determined by its radius, thickness
//position/orientation by its center, axis
//from these we compute auxilary quantities: sphere rad and 2 centers

struct Lens{
    float radius;
    float thickness;
    Point center;
    vec3 axis;
    Material mat;
    float R;
    Point c1;
    Point c2;
};



void setLens(inout Lens lens, float r,float d, Point center, vec3 axis){
    //compute sphere radius:
    
    lens.radius=r;
    lens.thickness=d;
    lens.center=center;
    lens.axis=normalize(axis);
    
    //compute auxillary quantities
    float R=(r*r+d*d)/(2.*d);
    Point c1,c2;
    c1.coords=center.coords+(R-d)*axis;
    c2.coords=center.coords-(R-d)*axis;
    
    lens.R=R;
    lens.c1=c1;
    lens.c2=c2;
}




float lensDist(vec3 pos,Lens lens){
    

    float dist1=sphDist(pos,Sphere(lens.c1,lens.R,lens.mat));
    float dist2=sphDist(pos,Sphere(lens.c2,lens.R,lens.mat));
    
    return max(dist1,dist2);
}



Vector lensNormal(Vector tv,Lens lens){
    
    Sphere sph1=Sphere(lens.c1,lens.R,lens.mat);
    Sphere sph2=Sphere(lens.c2,lens.R,lens.mat);
    
    float s1=abs(sphDist(tv.pos.coords,sph1));
    float s2=abs(sphDist(tv.pos.coords,sph2));
    
    if(s1<s2){//closer to surface of s1 than s2
        return sphereNormal(tv,sph1);
    }
    return sphereNormal(tv,sph2);

}





float lensSDF(Vector tv, Lens lens, inout localData dat){
    
    
    float d= lensDist(tv.pos.coords,lens);
    
    //-----------------
    
    if(d<EPSILON){//set the material
        dat.isSky=false;
        dat.normal=lensNormal(tv,lens);
        dat.mat=lens.mat;
    }
    
    return d;
    
}