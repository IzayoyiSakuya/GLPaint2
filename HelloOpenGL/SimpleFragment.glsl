uniform sampler2D texture;
varying lowp vec4 DestinationColor; 
void main ( )
{
    gl_FragColor = texture2D(texture, gl_PointCoord) * DestinationColor;
//gl_FragColor = vec4(1.0,0.0,0.0,1.0);

}

