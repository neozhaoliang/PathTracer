//-------------------------------------------------
// PATH-TRACING
// this is the main path tracing loop
//  used in main.glsl
//-------------------------------------------------


vec3 pathTrace(Path path){

        maxBounces=50;

        for (int bounceIndex = 0; bounceIndex < maxBounces; ++bounceIndex)
        {
                //move forward until the next intersection, update localData
                stepForward(path);

                //help with focusing
                focusCheck(path);

                //pick up color from traveling through the medium
                updateFromVolume(path);

                // if you hit the sky: stop
                updateFromSky(path);

                //scatter the path off in a new direction
                scatter(path);

                if(path.subSurface){
                       //do the subsurface scattering
                        subSurfScatter(path);
                        //update the color
                        updateFromSubSurf(path);
                }
                else{
                        //pick up any color from the reflection off surface
                        updateFromSurface(path);
                }

                //probabilistically kill rays
                roulette(path);

                if(!path.keepGoing){ break; }

        }



        return path.pixel;

}
