
//-------------------------------------------------
//Uniforms
//-------------------------------------------------

uniform vec3 iResolution;
uniform float iTime;
uniform sampler2D sky;
uniform sampler2D skySM;
uniform sampler2D acc;
uniform float iFrame;
uniform mat3 facing;
uniform vec3 location;
uniform float seed;




//-------------------------------------------------
//Constants
//-------------------------------------------------


// constants
float EPSILON=0.001;
int maxMarchSteps=100;
float maxDist=50.;
float fov=130.;
int maxBounces=30;

float PI=3.1415926535;























//-------------------------------------------------
//Post-Processing
//-------------------------------------------------



vec3 LessThan(vec3 f, float value)
{
    return vec3(
        (f.x < value) ? 1.0f : 0.0f,
        (f.y < value) ? 1.0f : 0.0f,
        (f.z < value) ? 1.0f : 0.0f);
}


vec3 LinearToSRGB(vec3 rgb)
{
    rgb = clamp(rgb, 0.0f, 1.0f);
    
    return mix(
        pow(rgb, vec3(1.0f / 2.4f)) * 1.055f - 0.055f,
        rgb * 12.92f,
        LessThan(rgb, 0.0031308f)
    );
}

vec3 SRGBToLinear(vec3 rgb)
{   
    rgb = clamp(rgb, 0.0f, 1.0f);
    
    return mix(
        pow(((rgb + 0.055f) / 1.055f), vec3(2.4f)),
        rgb / 12.92f,
        LessThan(rgb, 0.04045f)
	);
}













//-------------------------------------------------
//Random Number Generators
//-------------------------------------------------




uint wang_hash(inout uint seed)
{
    seed = uint(seed ^ uint(61)) ^ uint(seed >> uint(16));
    seed *= uint(9);
    seed = seed ^ (seed >> 4);
    seed *= uint(0x27d4eb2d);
    seed = seed ^ (seed >> 15);
    return seed;
}
 
float RandomFloat01(inout uint state)
{
    return float(wang_hash(state)) / 4294967296.0;
}
 
vec3 RandomUnitVector(inout uint state)
{
    float z = RandomFloat01(state) * 2.0f - 1.0f;
    float a = RandomFloat01(state) * 6.28;
    float r = sqrt(1.0f - z * z);
    float x = r * cos(a);
    float y = r * sin(a);
    return vec3(x, y, z);
}



//--- the function we call in main() which sets rngState
//--- based on the frag coord and the frame number

uint randomSeed(vec2 fCoord,float frame){

uint rngState = uint(uint(fCoord.x) * uint(1973) + uint(fCoord.y) * uint(925277) + uint(frame) * uint(26699)) | uint(1);

return rngState;

}










//-------------------------------------------------
//Utilities
//-------------------------------------------------

vec3 checkerboard(vec2 v){
    float x=mod(20.*v.x/6.28,2.);
    float y=mod(20.*v.y/3.14,2.);
    
    if(x<1.&&y<1.||x>1.&&y>1.){
        return vec3(1.);
    }
    else return vec3(0.0);
}



vec2 toSphCoords(vec3 v){
float theta=atan(-v.z,v.x);
float phi=acos(v.y);
return vec2(theta,phi);
}



vec3 toSphCoordsNoSeam(vec3 v){
    
    float theta=atan(-v.z,v.x);
    float theta2=atan(v.y,abs(v.x));
    float phi=acos(v.y);
return vec3(theta,phi,theta2);
}








//-------------------------------------------------
//Backgrounds
//-------------------------------------------------


vec3 skyTex(vec3 v){

vec3 angles=toSphCoordsNoSeam(v);
    
//theta coordinates (x=real, y=to trick the derivative so there's no seam)
float x=(angles.x+3.1415)/(2.*3.1415);
float z=(angles.z+3.1415)/(2.*3.1415);
    
float y=1.-angles.y/3.1415;

vec2 uv=vec2(x,y);
vec2 uv2=vec2(z,y);//grab the other arctan piece;
    
return SRGBToLinear(textureGrad(sky,uv,dFdx(uv2), dFdy(uv2)).rgb);

}




vec3 checkerTex(vec3 v){
    vec2 p=toSphCoords(v);
    return checkerboard(p);
}











//----------------------------------------------------------------------------------------------------------------------
// Ellitpic integrals and functions
//----------------------------------------------------------------------------------------------------------------------


/*

   Each pixel only involves a single geodesic.
   Hence all the parameters appearing in the elliptic integrals can be pre-computed once for all before marching.
   We store them in global variables.
   The names refer to the Remi's handwritten notes (following closely Troyanov's paper).
   The prefix ``ell`` is used to avoid any ambiguity

*/

// constants, purely related to the elliptic integrals / functions
float ell_k;
float ell_kprime;
float ell_m;
float ell_K;
float ell_E;

// constants related to the parametrization of the geodesic, but only depending on the trajectory of the geodesic
float ell_mu;
float ell_L;


/*

    *** Legendre elliptic integrals ***

    The modulus/parameter  k / k' / m are always implicit.
    We use the corresponding global variable to avoid redundant computations.

    The sources for the algorithms are:

    [1] Frank W. J. Olver, Daniel W. Lozier, Ronald F. Boisvert, Charles W. Clark
    NIST handbook of mathematical functions
    Cambridge University Press (2010)

    [2] Milton Abramowitz, Irene A. Stegun
    Handbook of Mathematical Functions_ with Formulas, Graphs, and Mathematical Tables
    National Bureau of Standards (1970)

    [3] Bulirsch, Roland
    Numerical calculation of elliptic integrals and elliptic functions
    Numer. Math. (7) 78--90 (1965)
    DOI: 10.1007/BF01397975


    TODO.
        - Reduce the number of local variables when computing an iteration.
        e.g. to compute the AGM, no need of a1 and g1, just a single temporary variable
        - Factor the AGM computations.
        There are indeed the same for all the elliptic functions, and thus alogn the geodesic.
        They could be pre-computed and stored in a global variable

*/

// maximal number of steps in the AGM algorithm
const int AGMSteps = 20;
// tolerance of the AGM algorithm
const float AGMTolerance = 0.000001;
// steps performed to compute the AGM (useful for the Jacobi functions)
// the coordinates of the stored vec3 have the following meaning
// - x : arithmetic mean
// - y : geometric mean
// - z : error
vec3 AGMList[AGMSteps];
// number of steps actually used for the AGM, the index of the last non-zero entries in AGMList should be AGMLength - 1
int AGMLength;

void agm() {
    // Compute the AGM of 1 and sqrt(1-m) to the given accuracy :
    // Note that sqrt(1 - m) = kprime
    // maximal number of steps : AGMMaxSteps
    // tolerance for the error : AGMTolerance
    // index of the last step : AGMIndex

    // initialization
    AGMList[0] = vec3(1., ell_kprime, ell_k);
    AGMLength = 1;

    // variable used during the induction
    float a0;
    float g0;
    float error;

    // induction
    for (int i = 1; i < AGMSteps; i++) {
        a0 = AGMList[i - 1].x;
        g0 = AGMList[i - 1].y;
        error = 0.5 * (a0 - g0);

        if (error < AGMTolerance) {
            break;
        }

        AGMList[i] = vec3(0.5 * (a0 + g0), sqrt(a0 * g0), error);
        AGMLength = AGMLength + 1;
    }
}

vec2 ellipke() {
    // Return the complete integeral of the first and second kind
    // Computed with the AGM method, see 19.8(i) in [1]

    // initialization of all the variables;
    float aux = 0.;

    // induction
    for (int i = 0; i < AGMLength; i++) {
        aux = aux + pow(2., float(i-1)) * AGMList[i].z * AGMList[i].z;
    }

    // wrapping up the results
    float K = 0.5 * PI / AGMList[AGMLength - 1].x;
    float E = K * (1. - aux);
    return vec2(K, E);
}

vec3 ellipj1(float u) {
    // Return the 3 Jacobi ellpitic functions sn(u|m), cn(u|m) and dn(u|m)
    // The results is output as [sn, cn, dn]
    // Computed with the AGM method, see Algorithm 5 in [3]
    // Note that the algorithm only makes sense if u is not zero.
    // u is asumme to be between 0 and 2 * K

    // initialization of all the variables
    float a0 = AGMList[AGMLength - 1].x;
    float g0 = AGMList[AGMLength - 1].y;

    float eps = 1.;
    if (sin(u * a0) < 0.) {
        eps = -1.;
    }

    // variables used during the second induction

    float c = a0 * cos(u * a0) / sin(u * a0);
    float d = 1.;
    float aux_c;
    float aux_d;
    float num;
    float den;

    for (int j = 1; j < AGMLength; j++) {
        aux_c = c * d;
        num = (c * c / AGMList[AGMLength - j].x + AGMList[AGMLength - 1 - j].y);
        den = (c * c / AGMList[AGMLength - j].x + AGMList[AGMLength - 1 - j].x);
        aux_d =  num / den;
        c = aux_c;
        d = aux_d;
    }

    // wrappind the results
    float sn = eps / sqrt(1. + c * c);
    float cn = c * sn;
    float dn = d;

    return vec3(sn, cn, dn);
}


vec3 ellipj2(float u) {
    // Return the 3 Jacobi ellpitic functions sn(u|m), cn(u|m) and dn(u|m)
    // The results is output as [sn, cn, dn]
    // Computed with an other AGM method, see 22.20(ii) in [1]
    // u is asumme to be between 0 and 2 * K

    // initializing the parameters for the induction
    float phi0 = pow(2., float(AGMLength-1)) * AGMList[AGMLength - 1].x * u;
    float phi1;
    float aux;


    for (int i = 1; i < AGMLength; i++) {
        aux = AGMList[AGMLength - i].z / AGMList[AGMLength - i].x;
        phi1 = 0.5 * (phi0 + asin(aux * sin(phi0)));
        phi0 = phi1;
    }

    float sn = sin(phi0);
    float cn = cos(phi0);
    float dn = sqrt(1. - ell_m * sn * sn);
    return vec3(sn, cn, dn);

}


vec3 ellipj3(float u) {
    // Return the 3 Jacobi ellpitic functions sn(u|m), cn(u|m) and dn(u|m)
    // Taken from ShaderToy: https://www.shadertoy.com/view/4tlBRl

    float emc = 1.0-ell_m;
    float a, b, c;
    const int N = 4;
    float em[N], en[N];
    a = 1.0;
    float dn = 1.0;
    for (int i = 0; i < N; i++) {
        em[i] = a;
        emc = sqrt(emc);
        en[i] = emc;
        c = 0.5*(a+emc);
        emc = a*emc;
        a = c;
    }
    // Nothing up to here depends on u, so
    // could be precalculated.
    u = c*u;
    float sn = sin(u);
    float cn = cos(u);
    if (sn != 0.0) {
        a = cn/sn; c = a*c;
        for (int i = N-1; i >= 0; i--) {
            b = em[i];
            a = c*a;
            c = dn*c;
            dn = (en[i]+a)/(b+a);
            a = c/b;
        }
        a = 1.0/sqrt(c*c + 1.0);
        if (sn < 0.0) sn = -a;
        else sn = a;
        cn = c*sn;
    }

    return vec3(sn, cn, dn);
}


vec3 ellipjAtZero(float u) {
    // Asymptotic expansion around u = 0 of the Jacobi elliptic functions sn, cn and dn
    // We use the MacLaurin series, see 22.10(i) in [1]

    float k2 = ell_m;
    float k4 = ell_m * ell_m;
    float k6 = k4 * ell_m;

    float u1 = u;
    float u2 = u1 * u;
    float u3 = u2 * u;
    float u4 = u3 * u;
    float u5 = u4 * u;
    float u6 = u5 * u;
    float u7 = u6 * u;

    return vec3(
    u1
    - (1. + k2) * u3 / 6.
    + (1. + 14. * k2 + k4) * u5 / 120.
    - (1. + 135. * k2 + 135. * k4 + k6) * u7 / 5040.,

    1.
    - u2 / 2.
    + (1. + 4. * k2) * u4 / 24.
    - (1. + 44. * k2 + 16. * k4) * u6 / 720.,

    1.
    - k2 * u2 / 2.
    + k2 * (4. + k2) * u4 / 24.
    - k2 * (16. + 44. * k2 + k4) * u6 / 720.
    );
}



vec3 ellipj(float u) {
    // reducing the computation using the periodicity and symmetries of the Jacobi elliptic functions
    // dispatching which algorithm is used to compute the result
    float tolerance = 0.001;


    float u1 = mod(u, 4. * ell_K);
    float sign = 1.;
    if (u1 > 2. * ell_K) {
        u1 = 4.* ell_K -u1;
        sign = -1.;
    }

    vec3 aux;

    if (u1 < tolerance) {
        aux = ellipjAtZero(u1);
    }
    else {
        aux = ellipj1(u1);
    }

    return vec3(sign * aux.x, aux.y, aux.z);
}


float ellipz(float tanPhi) {
    // Return the Jacobi Zeta function, whose argument is an angle phi passed as tan(phi), i.e.
    // Z(phi|m) = E(phi|m) - [E(m)/K(m)] * F(phi|m)
    // the argument is passed as tan(phi) since this is the way it is computed from the Jacboi function :
    // tan(phi) = sn(u|m) / cn(u|m)
    // This is useless to compute the atan and then apply tan!
    // Computed with the AGM algorithm, see §17.6 in [2]
    float tolerance = 0.001;


    float sign = 1.;
    float t0 = tanPhi;
    if (t0 < 0.) {
        t0 = - t0;
        sign = -1.;
    }

    float res = 0.;

    // if t0 is close to zero we use an asymptotic expansion around zero
    // (computed with SageMath)
    if (t0 < tolerance) {
        float k2 = ell_m;
        float k4 = k2 * ell_m;
        float k6 = k4 * ell_m;
        res =  - (ell_E /ell_K - 1.) * t0;
        res = res - (1./6.) * (ell_E * k2 / ell_K + k2 - 2. * ell_E / ell_K + 2.) * pow(t0, 3.);
        res = res - (1./40.) * (3. * ell_E * k4 / ell_K + k4 - 8. * ell_E * k2 / ell_K - 8. * k2 + 8. * ell_E / ell_K - 8.) * pow(t0, 5.);
        res = res - (1./112.) * (5. * ell_E * k6 / ell_K + k6 - 18. * ell_E * k4 / ell_K - 6. * k4 + 24. * ell_E * k2 / ell_K + 24. * k2 - 16. * ell_E / ell_K + 16.) * pow(t0, 7.);
    }
    else {
        // initializing the parameters of the induction

        float t1;// represent tan(phi_{n+1})
        float s1;// represent sin(phi_{n+1})
        float aux;

        for (int i = 0; i < AGMLength; i++) {
            aux = AGMList[i].y / AGMList[i].x;
            t1 = t0 * (1. + aux) / (1. - aux * t0 * t0);
            s1 = t0 * (1. + aux) / sqrt((1. + t0 * t0) * (1. + aux * aux * t0 * t0));
            res = res + AGMList[i + 1].z * s1;

            t0 = t1;
        }
    }
    return sign * res;
}









