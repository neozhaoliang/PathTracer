#version 300 es
out vec4 out_FragColor;


//----------------------------------------------------------------------------------------------------------------------
// PARAMETERS
//----------------------------------------------------------------------------------------------------------------------
float test;
vec2 test2;
vec3 test3;
vec4 test4;
/*

Some parameters that can be changed to change the scence
*/

//----------------------------------------------------------------------------------------------------------------------
// "TRUE" CONSTANTS
//----------------------------------------------------------------------------------------------------------------------

const float PI = 3.1415926538;
const float sqrt3 = 1.7320508075688772;
const float sqrt2 = 1.4142135623730951;


//----------------------------------------------------------------------------------------------------------------------
// Global Constants
//----------------------------------------------------------------------------------------------------------------------
float MAX_DIST = 30.0;
const float EPSILON = 0.0001;
const float fov = 90.0;



//----------------------------------------------------------------------------------------------------------------------
// Global Variables
//----------------------------------------------------------------------------------------------------------------------

int inWhich=0;
int hitWhich = 0;

//set by raymarch
float distToViewer;
bool isSky=false;
float side;
//remember which side of the object youre on when the raymarch ends





//----------------------------------------------------------------------------------------------------------------------
// Translation & Utility Variables
//----------------------------------------------------------------------------------------------------------------------
uniform vec2 screenResolution;
uniform mat4 currentBoostMat;
uniform mat4 facing;





//----------------------------------------------------------------------------------------------------------------------
// Lighting Variables & Global Object Variables
//----------------------------------------------------------------------------------------------------------------------

uniform sampler2D tex;






//color of the sky
//vec4 skyColor=vec4(0.,0.,0.,1.);
vec4 skyColor=vec4(0.5,0.6,0.7,.8);






