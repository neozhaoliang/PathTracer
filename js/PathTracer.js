import {WebGLRenderer} from "./libs/three.module.js";


import ComputeShader from "./ComputeShader.js";
import KeyControls from "./KeyControls.js";




//class to run the path tracer from
class PathTracer{
    constructor(shaders, canvas, res={x:window.innerWidth,y:window.innerHeight}) {

        //save the canvas
        this.canvas = canvas;
        //build the renderer
        this.renderer = new WebGLRenderer({canvas: canvas});
        this.renderer.setSize(res.x,res.y);

        //the control system
        this.controls = new KeyControls();

        //the shaders
        this.tracer = new ComputeShader(shaders.tracer, this.renderer,res);
        this.accumulate = new ComputeShader(shaders.accumulate, this.renderer,res);
        this.display = new ComputeShader(shaders.display, this.renderer,res);

    }

    updateUniforms(){
        this.tracer.material.uniforms.frameSeed.value +=1.;
        this.accumulate.material.uniforms.frameNumber.value += 1.;

        if(this.controls.isPressed()){
            this.controls.update();
            this.tracer.updateUniforms({
                facing: this.controls.facing,
                location: this.controls.position,
            });
           this.reset();
        }
    }



    newFrame(){

        this.updateUniforms();

        //render a new frame
        this.tracer.render();
        this.accumulate.updateUniforms({new: this.tracer.getData()} );

        //accumulate it
        this.accumulate.render();
        this.accumulate.updateUniforms({acc: this.accumulate.getData()} );
        this.display.updateUniforms({acc: this.accumulate.getData()} );

        //display it
         this.display.renderToScreen();

    }

    reset(){
        this.tracer.updateUniforms({frameSeed:0});
        this.accumulate.updateUniforms({frameNumber:0});
    }


    saveImage(){
        // // Grab the canvas element
        // let canvas = document.getElementById("World");
        // console.log(canvas);
        // // Create a PNG image of the pixels drawn on the canvas using the toDataURL method.
        // let dataURL = canvas.toDataURL("image/png");
        // // Create a dummy link text
        // let a = document.createElement('a');
        // // Set the link to the image so that when clicked, the image begins downloading
        // a.href = dataURL
        // // Specify the image filename
        // a.download = `${this.compute.material.uniforms.frameSeed.value}`+'.png';
        // // Click on the link to set off download
        // a.click();
        // //remove this element fromm the doc
        // //document.removeChild(a);
    }

    resize(res){
        this.tracer.setSize(res);
        this.accumulate.setSize(res);
        this.display.setSize(res);
        this.renderer.setSize(res.x,res.y);
    }

}


export default PathTracer;