


//if you hit an object which is not part of a compound, one side is the object (material) and the other side is air
//set your local data appropriately
void setObjectInAir(inout localData dat, float side, Vector normal, Material mat){

    //set the material
    dat.isSky=false;
    dat.surfDiffuse=mat.diffuseColor;
    dat.surfSpecular=mat.specularColor;
    dat.surfEmit=mat.emitColor;
    dat.surfRoughness=mat.roughness;
    dat.probDiffuse=1.-mat.specularChance-mat.refractionChance;
    dat.probSpecular=mat.specularChance;
    dat.probRefract=mat.refractionChance;

    if(side<0.){
        //we are inside
        dat.normal=negate(normal);
        //IOR is current/enteing
        dat.IOR=mat.IOR/1.;
        dat.reflectAbsorb=mat.absorbColor;
        dat.refractAbsorb=vec3(0.);
    }

    else{
        //we are outside
        dat.normal=normal;
        //IOR is current/enteing
        dat.IOR=1./mat.IOR;
        dat.reflectAbsorb=vec3(0.);
        dat.refractAbsorb=mat.absorbColor;
    }

}







//-------------------------------------------------
// The NEW FUNCTIONS
//-------------------------------------------------


void updateFromVolume(inout Path path){

    vec3 beersLaw = path.absorb*path.distance;

    if(length(beersLaw)>0.001){
        path.light *= exp( -beersLaw );
    }
}


void updateFromSurface(inout Path path){

    //add in emissive lighting
    if(length(path.dat.surfEmit)>0.){
        path.pixel += path.light * path.dat.surfEmit;
    }

    //pick up some surface color upon reflection
    if(path.type == 1){
        path.light *=  path.dat.surfDiffuse;
    }
    if(path.type == 2){
        path.light *=  path.dat.surfSpecular;
    }

}



void updateFromSky(inout Path path){
    if(path.dat.isSky){
        vec3 skyColor = skyTex(path.tv.dir);
        //vec3 skyColor=vec3(0.5);
        path.pixel += path.light*skyColor;
        path.keepGoing = false;
    }
}



void focusCheck(inout Path path){
//    if(abs(path.distance-focalLength)<0.5&&focusHelp){
//        path.pixel+=vec3(1.,0.,0.);
//    }
}



void roulette(inout Path path){

    // As the light left gets smaller, the ray is more likely to get terminated early.
    // Survivors have their value boosted to make up for fewer samples being in the average.

    float p = LInf_Norm(path.light);
    if (randomFloat() > p){
        path.keepGoing = false;
    }
    // Add the energy we 'lose' by randomly terminating paths
    //if(p>0.001){
        path.light *= 1. / p;
   // }
}



