precision mediump float;
uniform float u_bass;
uniform float u_mid;
uniform float u_treble;

void main() {
    gl_FragColor = vec4(u_bass, u_mid, u_treble, 1.0);
}
