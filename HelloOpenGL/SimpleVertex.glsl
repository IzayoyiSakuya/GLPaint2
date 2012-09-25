attribute vec4 Position; 
attribute vec4 SourceColor; 
uniform mat4 Projection;

//uniform mat4 ModelView;
//uniform float uThickness;

varying vec4 DestinationColor; 

void main(void) { 
    DestinationColor = SourceColor; 

    gl_Position =  Position * Projection;

    gl_PointSize = 15.0;
}
//    gl_PointSize = uThickness;
//    gl_Position = Projection * ModelView * Position;