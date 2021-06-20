


//-------------------------------------------------
// The ROOTFINDING LOOP: FOR VARIETIES
//-------------------------------------------------


float sexticEqn(vec3 pos){

    float scale=1.;
    vec3 center=vec3(0,0,0);

    float x=scale*(pos.x-center.x);
    float y=scale*(pos.y-center.y);
    float z=scale*(pos.z-center.z);

    float t = 1.618034;
    return 4.*(t*t*x*x - y*y ) * ( t*t *y*y - z*z ) *( t*t* z*z - x*x )
    - ( 1. + 2.*t) *(x*x + y*y + z*z- 1.)*(x*x + y*y + z*z- 1.);
}

float fermat(vec3 pos,float n){

    float scale=1.;
    vec3 center=vec3(0,0,0);

    float x=scale*(pos.x-center.x);
    float y=scale*(pos.y-center.y);
    float z=scale*(pos.z-center.z);


    return pow(x,abs(n))+pow(y,abs(n))+pow(z,abs(n))-1.;

}

float roman(vec3 pos){

    float scale=2.;
    vec3 center=vec3(0,0,-2);

    float x=scale*(pos.x-center.x);
    float y=scale*(pos.y-center.y);
    float z=scale*(pos.z-center.z);

    float x2=x*x;
    float y2=y*y;
    float z2=z*z;

    return x2*y2+y2*z2+z2*x2-2.*x*y*z;

}

float chmutov(vec3 pos,float c){

    float scale=2.;
    vec3 center=vec3(0,0,-2);

    float x=scale*(pos.x-center.x);
    float y=scale*(pos.y-center.y);
    float z=scale*(pos.z-center.z);

    float x2=x*x;
    float y2=y*y;
    float z2=z*z;

    return 8.*(x2*x2 + y2*y2 + z2*z2) - 8.*(x2 + y2 + z2) + 3.-c;

}



float gyroid(vec3 pos){
    float scale=2.;
    vec3 center=vec3(0,0,-2);

    float x=scale*(pos.x-center.x);
    float y=scale*(pos.y-center.y);
    float z=scale*(pos.z-center.z);

    return sin(x)*cos(y)+sin(y)*cos(z)+sin(z)*cos(x);
}



//float kummer(vec3 pos,float mu){
//
//    float scale=2.;
//    vec3 center=vec3(0,0,-2);
//
//    float x=scale*(pos.x-center.x);
//    float y=scale*(pos.y-center.y);
//    float z=scale*(pos.z-center.z);
//    float w=1.;
//
//    float x2=x*x;
//    float y2=y*y;
//    float z2=z*z;
//    float w2=w*w;
//
//    float x4=x2*x2;
//    float y4=y2*y2;
//    float z4=z2*z2;
//    float w4=w2*w2;
//
//    float a=1.;
//    float b=1.;
//    float c=1.;
//    float d=-0.0;
//
//    float term1=x4+y4+z4+w4;
//    float term2=2.*x*y*z*w;
//    float term3=x2*y2+z2*w2;
//    float term4=x2*z2+y2*w2;
//    float term5=x2*w2+y2*z2;
//
//    return term1+d*term2-a*term3-b*term4-c*term5;
//
//}





float kummer(vec3 pos,float mu){

    float scale=1.;
    vec3 center=vec3(0,0,-2.);

    float x=scale*(pos.x-center.x);
    float y=scale*(pos.y-center.y);
    float z=scale*(pos.z-center.z);

    float x2=x*x;
    float y2=y*y;
    float z2=z*z;

    float mu2=mu*mu;
    float lambda=(3.*mu*mu-1.)/(3.-mu*mu);
    float sqrt2=sqrt(2.);

    float p=1.-z-sqrt2*x;
    float q=1.-z+sqrt2*x;
    float r=1.+z+sqrt2*y;
    float s=1.+z-sqrt2*y;

    float quad=x2+y2+z2-mu2;

    return quad*quad-lambda*p*q*r*s;
}

float variety(vec3 pos){
    // return fermat(pos,4.);
    //return chmutov(pos,-1.);
    //return  sexticEqn(pos);

    return kummer(pos,1.3);

}




















float variety(Vector tv){
    return variety(tv.pos.coords.xyz);
}


vec3 gradient(Vector tv){

    vec3 pos=tv.pos.coords.xyz;

    const float ep = 0.0001;
    vec2 e = vec2(1.0,-1.0)*0.5773;

    float vxyy=variety( pos + e.xyy*ep);
    float vyyx=variety( pos + e.yyx*ep);
    float vyxy=variety( pos + e.yxy*ep);
    float vxxx=variety( pos + e.xxx*ep);

    vec3 dir=  e.xyy*vxyy + e.yyx*vyyx + e.yxy*vyxy + e.xxx*vxxx;

    return normalize(dir);
}

























float bBox(Vector tv){
    vec3 center=vec3(0,0,-2.);
    vec3 pos=tv.pos.coords.xyz-center;
    return length(pos)-5.;
}


float marchBBox(inout Vector tv){

    float distToScene=0.;
    float totalDist=0.;

    float marchDist;

    Vector temp=tv;

    for (int i = 0; i < maxMarchSteps; i++){

        distToScene =bBox(temp);
        marchDist=distToScene;

        if (distToScene< EPSILON){
            flow(tv,totalDist);
            return totalDist;
        }

        totalDist += marchDist;

        if(totalDist>maxDist){
            break;
        }

        //otherwise keep going
        flow(temp, marchDist);
    }

    //if you hit nothing
    flow(tv,maxDist);
    return maxDist;
}


float setStepSize(Vector tv){

    float dist=abs(variety(tv));

    if(dist>10.){
        return 0.1;
    }
    else if(dist>0.2){
        return 0.01;
    }
    else{
        return 0.001;
    }
}


bool changeSign(Vector u, Vector v){
    float x=variety(u);
    float y=variety(v);
    if(x*y<0.){
        return true;
    }
    return false;
}


void binarySearch(inout Vector tv,inout float dt){
    //given that you just passed changed sign, find the root
    float dist=0.;
    //flowing dist from tv doesnt hit the plane, dist+dt does:
    float testDist=dt;
    Vector temp;
    for(int i=0;i<10;i++){

        //divide the step size in half
        testDist=testDist/2.;

        //test flow by that amount:
        temp=tv;
        flow(temp, dist+testDist);
        //if you are still above the plane, add to distance.
        if(!changeSign(temp,tv)){
            dist+=testDist;
        }
        //if not, then don't add: divide in half and try again

    }

    //step tv ahead by the right ammount;
    flow(tv,dist);

}




float findRoot(inout Vector tv, inout localData dat){

    float marchStep = 0.;
    float depth=0.;
    float dt;

    Vector temp=tv;
    vec3 dir;
    Vector normal;
    float side;
    float boundingBox=20.;

    //before beginning the root find, first march tv forward until we hit the bounding box:
    depth=marchBBox(tv);
    flow(tv,2.*EPSILON);

    //now look for a zero inside the bounding box
    for (int i = 0; i <2500; i++){

        //determine how far to test flow from current location
        dt=setStepSize(tv);

        //temporarily step forward that distance along the ray
        temp=tv;
        flow(temp,dt);

        //check if we crossed the surface:f
        if(changeSign(temp,tv)){
            //set side based on orig position:
            side=variety(tv);

            //use a binary search to give exact intersection
            binarySearch(tv,dt);

            //set all the data:
            dir=gradient(tv);
            normal=Vector(tv.pos,dir);
            // setObjectInAir(dat,side,normal,ball3.mat);
            setSurfaceInAir(dat,side,normal,ball2.mat);
            return depth+dt;
        }

        //if we didn't cross the surface, move tv ahead by this step
        tv=temp;
        //increase the total distance marched
        depth+=dt;


        //check if we escaped the bounding box
        if(bBox(tv)>EPSILON){
            //if so, raymarch the scene to see where we get:
            return depth+raymarch(tv,dat);
        }
    }

    //hit nothing
    //    dat.isSky=true;
    flow(tv,depth);
    return depth;
}








//
//float findRoot(inout Vector tv, inout localData dat){
//    return 500.;
//}
//
