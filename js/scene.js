        //Import Stuff
        //=============================================
        import * as THREE from './libs/three.module.js';

        import {
            rotControls,
            translControls
        } from './controls.js';


        import{ui} from "./ui.js";

        //Scene Variables
        //=============================================


        //background sky texture
        const skyTex = new THREE.TextureLoader().load('/js/tex/bk.jpg');


        //background sky texture
        const skyTexSmall = new THREE.TextureLoader().load('/js/tex/bk_sm.jpg');



        // things for building display and accumulation scenes
        let accScene, dispScene,combineScene;
        let accMaterial, dispMaterial,combineMaterial;
        let accUniforms, dispUniforms,combineUniforms;
        let accShader, dispShader,combineShader;









        //Build Accumulation Scene
        //=============================================





        async function buildAccShader() {

            let newShader = '';


            const shaders = [] = [
                {
                    file: '../glsl/accShader/01setup.glsl'
                },
                {
                    file: '../glsl/accShader/02random.glsl'
                },
                {
                    file: '../glsl/accShader/03spectral.glsl'
                },
                {
                    file: '../glsl/accShader/04geometry.glsl'
                },
                {
                    file: '../glsl/accShader/05materials.glsl'
                },
                {
                    file: '../glsl/accShader/06path.glsl'
                },
                {
                    file: '../glsl/accShader/07BSDF.glsl'
                },
                {
                    file: '../glsl/accShader/08distanceFields.glsl'
                },
                {
                    file: '../glsl/accShader/09basicObjects.glsl'
                },
                           {
                    file: '../glsl/accShader/10compoundObjects.glsl'
                },
                {
                    file: '../glsl/accShader/11scene.glsl'
                },
                {
                    file: '../glsl/accShader/12trace.glsl'
                },
                {
                    file: '../glsl/accShader/13render.glsl'
                },
                {
                    file: '../glsl/accShader/14accumulate.glsl'
                },
    ];


            //loop over the list of files
            let response, text;
            for (const shader of shaders) {
                response = await fetch(shader.file);
                text = await response.text();
                newShader = newShader + text;
            }

            return newShader;

        }




        async function createAccShaderMat() {

            //OLD WAY: LOAD SINGLE SHADER
            //            const accText = await fetch('../glsl/accShader.glsl');
            //            accShader = await accText.text();
            //build the shader out of files

            //build the shader text
            accShader = await buildAccShader();

            accUniforms = {
                iTime: {
                    value: 0
                },
                iResolution: {
                    value: new THREE.Vector3(window.innerWidth, window.innerHeight, 0.)
                },
                //frame number we are on
                iFrame: {
                    value: 0
                },
                sky: {
                    value: skyTex
                },
                skySM: {
                    value: skyTexSmall
                },
                //accumulated texture
                acc: {
                    value: null
                },
                facing: {
                    value: new THREE.Matrix3().identity()
                },
                location: {
                    value: new THREE.Vector3(0, 0, 0)
                },
                seed: {
                    value: 0
                },
               aperture: {
                    value: ui.aperture.value
                },
                focalLength: {
                    value: ui.focalLength.value
                },
                brightness: {
                    value: ui.brightness.value
                },
                focusHelp: {
                    value: ui.focusHelp.value
                },
                fov: {
                    value: ui.fov.value
                },
            };

        }


        function createAccScene(accShader, accUniforms) {



            //make the actual scene, and the buffer Scene
            accScene = new THREE.Scene();

            //make the plane we will add to both scenes
            const accPlane = new THREE.PlaneBufferGeometry(2, 2);

            accMaterial = new THREE.ShaderMaterial({
                fragmentShader: accShader,
                uniforms: accUniforms,
            });

            accScene.add(new THREE.Mesh(accPlane, accMaterial));

        }



        function updateAccUniforms() {



            //  accMaterial.uniforms.iResolution.value.set(canvas.width, canvas.height, 1);
            //  accMaterial.uniforms.iResolution.value.set(window.innerWidth, window.innerHeight);
            accMaterial.uniforms.iTime.value = 0;
            accMaterial.uniforms.iFrame.value += 1.;
            accMaterial.uniforms.seed.value += 1.;

            let rotData = rotControls();
            let mat = rotData[0];
            let detectRot = rotData[1];

            let translData = translControls(accMaterial.uniforms.facing.value);
            let vec = translData[0];
            let detectTransl = translData[1];

            if (detectRot || detectTransl) {

                accMaterial.uniforms.facing.value.multiply(mat);

                accMaterial.uniforms.location.value.add(vec);

                accMaterial.uniforms.iFrame.value = 0.;
            }


        }



        //Build Combine Scene
        //=============================================


        async function createCombineShaderMat() {

            const combineText = await fetch('../glsl/combine/combine.glsl');
            combineShader = await combineText.text();


            combineUniforms = {
                iFrame: {
                    value: 0
                    },
                iResolution: {
                    value: new THREE.Vector3(window.innerWidth, window.innerHeight, 0.)
                },
                acc: {
                    value: null
                },
                new: {
                    value: null
                }
            };
        }



        function createCombineScene(combineShader, combineUniforms) {


            //make the actual scene, and the buffer Scene
            combineScene = new THREE.Scene();


            //make the plane we will add to both scenes
            const combinePlane = new THREE.PlaneBufferGeometry(2, 2);


            combineMaterial = new THREE.ShaderMaterial({
                fragmentShader: combineShader,
                uniforms: combineUniforms,
            });


            combineScene.add(new THREE.Mesh(combinePlane, combineMaterial));


        }



        function updateCombineUniforms() {

            combineMaterial.uniforms.iFrame.value += 1.;


        }






        //Build Display Scene
        //=============================================


        async function createDispShaderMat() {

            const dispText = await fetch('../glsl/dispShader.glsl');
            dispShader = await dispText.text();


            dispUniforms = {
                //                iTime: {
                //                    value: 0
                //                },
                iResolution: {
                    value: new THREE.Vector3(window.innerWidth, window.innerHeight, 0.)
                },
                //                //frame number we are on
                //                iFrame: {
                //                    value: 0
                //                },
                //raw display texture
                acc: {
                    value: null
                }
            };


        }



        function createDispScene(dispShader, dispUniforms) {


            //make the actual scene, and the buffer Scene
            dispScene = new THREE.Scene();


            //make the plane we will add to both scenes
            const dispPlane = new THREE.PlaneBufferGeometry(2, 2);


            dispMaterial = new THREE.ShaderMaterial({
                fragmentShader: dispShader,
                uniforms: dispUniforms,
            });


            dispScene.add(new THREE.Mesh(dispPlane, dispMaterial));


        }



        function updateDispUniforms() {

            //dispMaterial.uniforms.iResolution.value.set(canvas.width, canvas.height, 1);
            // dispMaterial.uniforms.iResolution.value.set(window.innerWidth, window.innerHeight);
            //dispMaterial.uniforms.iFrame.value += 1.;
            //dispMaterial.uniforms.iTime.value = 0;

        }




        //Functions to Export
        //=============================================


        //run one time to set things up
        async function buildScenes() {

            await createAccShaderMat();

            createAccScene(accShader, accUniforms);

            await createDispShaderMat();

            createDispScene(dispShader, dispUniforms);

            await createCombineShaderMat();

            createCombineScene(combineShader, combineUniforms);

        }


        //updates materials each time a frame runs: resizing canvas if necessary
        function updateUniforms() {
            updateAccUniforms();
            updateCombineUniforms();
            updateDispUniforms();
        }



        export {
            accMaterial,
            combineMaterial,
            dispMaterial,
            accScene,
            combineScene,
            dispScene,
            buildScenes,
            updateUniforms
        }
