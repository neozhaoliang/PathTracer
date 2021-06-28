

//-------------------------------------------------
//Struct Camera
//-------------------------------------------------


struct Camera{
    vec3 pos;
    mat3 facing;
    float fov;
    float aperture;
    float focalLength;
};



Camera buildCamFromUniforms(){
    Camera cam;
    cam.pos=location;
    cam.facing=facing;
    cam.fov=fov;
    cam.aperture=aperture;
    cam.focalLength=focalLength;
    return cam;
}





//-------------------------------------------------
// INTERNAL TO THIS FILE
//-------------------------------------------------

//pinhole camera setup
Vector initializeRay(vec2 fragCoord,float FOV){

    // The ray starts at the camera position (a uniform)
    vec3 rayPosition = ORIGIN;

    // calculate subpixel camera jitter for anti aliasing
    vec2 jitter = vec2(randomFloat(), randomFloat()) - 0.5f;

    // calculate coordinates of the ray target on the imaginary pixel plane.
    vec2 planeCoords=((fragCoord+jitter)/iResolution.xy) * 2.0f - 1.0f;

    // correct for aspect ratio
    float aspectRatio = iResolution.x / iResolution.y;
    planeCoords.y /= aspectRatio;

    //move z-distance for fov:
    float z=-1./ tan(radians(FOV * 0.5));

    // -1 to +1 on x,y axis. 1 unit away on the z axis
    vec3 rayTarget = vec3(planeCoords, z);


    // calculate a normalized vector for the ray direction.
    // it's pointing from the ray position to the ray target.
    vec3 rayDir = normalize(rayTarget);

    //combine into tangent vector
    Vector tv=Vector(rayPosition,rayDir);

    return tv;

}



vec2 sampleAperture(Camera cam){

    float theta=2.*PI*randomFloat();
    float radius=cam.aperture*sqrt(randomFloat());

    vec2 offset=radius*vec2(cos(theta),sin(theta));
    return offset;
}






//-------------------------------------------------
// USED OUTSIDE THIS FILE
//  this sets up the initial ray in main.glsl
//-------------------------------------------------

Vector cameraRay(vec2 fragCoord, Camera cam){

    //set up pinhole camera at origin
    Vector tv=initializeRay(fragCoord,cam.fov);

    //find the focal point for the ray tv:
    vec3 focalPt=tv.pos+cam.focalLength*tv.dir;

    //reset the position by jittering inside the aperture
    vec2 offset=sampleAperture(cam);
    vec3 pos=tv.pos;
    pos.xy+=offset;

    //now set the direction based on the focal length:
    vec3 dir=normalize(focalPt-pos);

    //update the tangent vector
    tv=Vector(pos,dir);


    //rotate position to be in the right spot
    //THIS IS A HACK: BASED ON LENS BEING CENTERED AT ORIGIN
    //to be corect should first translate to origin; do this, then translate back
    tv.pos=facing*tv.pos;

    //translate by the right amount
    tv.pos+=cam.pos;


    //rotate by facing (a uniform)
    tv=rotateByFacing(tv,cam.facing);

    return tv;
}

