<script lang="ts">
	import { onMount } from "svelte";

	let canvas: HTMLCanvasElement;
	let gl: WebGLRenderingContext;
	let program: WebGLProgram;
	let timeLocation: WebGLUniformLocation;
	let resolutionLocation: WebGLUniformLocation;
	let startTime: number;

	const vertexShader = `
    attribute vec2 position;
    void main() {
      gl_Position = vec4(position, 0.0, 1.0);
    }
  `;

	const fragmentShader = `
    precision highp float;
    uniform float iTime;
    uniform vec2 iResolution;

    #define PIXEL_SIZE_FAC 700.0
    #define SPIN_EASE 0.5
    #define colour_2 vec4(0.0,156./255.,1.,1.0)
    #define colour_1 vec4(0.85,0.2,0.2,1.0)
    #define colour_3 vec4(0.0,0.0,0.0,1.0)
    #define spin_amount 0.7
    #define contrast 1.5

    void mainImage(out vec4 fragColor, in vec2 fragCoord) {
	   //Convert to UV coords (0-1) and floor for pixel effect
    float pixel_size = length(iResolution.xy)/PIXEL_SIZE_FAC;
    vec2 uv = (floor(fragCoord.xy*(1.0/pixel_size))*pixel_size - 0.5*iResolution.xy)/length(iResolution.xy) - vec2(0.0, 0.0);
    float uv_len = length(uv);

    //Adding in a center swirl, changes with iTime. Only applies meaningfully if the 'spin amount' is a non-zero number
    float speed = (iTime*SPIN_EASE*0.1) + 302.2;
    float new_pixel_angle = (atan(uv.y, uv.x)) + speed - SPIN_EASE*20.*(1.*spin_amount*uv_len + (1. - 1.*spin_amount));
    vec2 mid = (iResolution.xy/length(iResolution.xy))/2.;
    uv = (vec2((uv_len * cos(new_pixel_angle) + mid.x), (uv_len * sin(new_pixel_angle) + mid.y)) - mid);

	//Now add the paint effect to the swirled UV
    uv *= 30.;
    speed = iTime*(1.);
	vec2 uv2 = vec2(uv.x+uv.y);

    for(int i=0; i < 5; i++) {
		uv2 += uv + cos(length(uv));
		uv  += 0.5*vec2(cos(5.1123314 + 0.353*uv2.y + speed*0.131121),sin(uv2.x - 0.113*speed));
		uv  -= 1.0*cos(uv.x + uv.y) - 1.0*sin(uv.x*0.711 - uv.y);
	}

    //Make the paint amount range from 0 - 2
    float contrast_mod = (0.25*contrast + 0.5*spin_amount + 1.2);
	float paint_res =min(2., max(0.,length(uv)*(0.035)*contrast_mod));
    float c1p = max(0.,1. - contrast_mod*abs(1.-paint_res));
    float c2p = max(0.,1. - contrast_mod*abs(paint_res));
    float c3p = 1. - min(1., c1p + c2p);

    vec4 ret_col = (0.3/contrast)*colour_1 + (1. - 0.3/contrast)*(colour_1*c1p + colour_2*c2p + vec4(c3p*colour_3.rgb, c3p*colour_1.a)) + 0.3*max(c1p*5. - 4., 0.) + 0.4*max(c2p*5. - 4., 0.);

    fragColor = ret_col;
    }

	void main() {
		vec4 fragColor;
		mainImage(fragColor, gl_FragCoord.xy);
		gl_FragColor = fragColor;
	}
  `;

	function createShader(type: number, source: string): WebGLShader {
		const shader = gl.createShader(type);
		if (!shader) {
			throw new Error("Failed to create shader");
		}
		gl.shaderSource(shader, source);
		gl.compileShader(shader);

		if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
			const info = gl.getShaderInfoLog(shader);
			gl.deleteShader(shader);
			throw new Error("Shader compilation error: " + info);
		}

		return shader;
	}

	function initWebGL() {
		const context = canvas.getContext("webgl");
		if (!context) {
			throw new Error("WebGL not supported");
		}
		gl = context;

		const vertShader = createShader(gl.VERTEX_SHADER, vertexShader);
		const fragShader = createShader(gl.FRAGMENT_SHADER, fragmentShader);
		if (!vertShader || !fragShader) {
			throw new Error("Failed to create shaders");
		}

		const prog = gl.createProgram();
		if (!prog) {
			throw new Error("Failed to create program");
		}
		program = prog;

		gl.attachShader(program, vertShader);
		gl.attachShader(program, fragShader);
		gl.linkProgram(program);

		if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
			const info = gl.getProgramInfoLog(program);
			throw new Error("Program link error: " + info);
		}

		const tLocation = gl.getUniformLocation(program, "iTime");
		const rLocation = gl.getUniformLocation(program, "iResolution");

		// Check if uniforms exist in the shader
		if (tLocation === null || rLocation === null) {
			throw new Error(
				"Failed to get uniform locations: iTime or iResolution not found in shader",
			);
		}

		// Create and bind vertex buffer
		const positions = new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]);
		const buffer = gl.createBuffer();
		gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
		gl.bufferData(gl.ARRAY_BUFFER, positions, gl.STATIC_DRAW);

		// Get and enable the position attribute
		const positionLocation = gl.getAttribLocation(program, "position");
		gl.enableVertexAttribArray(positionLocation);
		gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);

		timeLocation = tLocation;
		resolutionLocation = rLocation;

		startTime = performance.now();
		render();
	}

	let animationFrame: number;

	function render() {
		const time = (performance.now() - startTime) * 0.001;
		gl.viewport(0, 0, canvas.width, canvas.height);
		gl.useProgram(program);
		gl.uniform1f(timeLocation, time);
		gl.uniform2f(resolutionLocation, canvas.width, canvas.height);
		gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
		animationFrame = requestAnimationFrame(render);
	}

	function handleResize() {
		canvas.width = window.innerWidth;
		canvas.height = window.innerHeight;
	}

	onMount(() => {
		handleResize();
		window.addEventListener("resize", handleResize);
		initWebGL();

		return () => {
			window.removeEventListener("resize", handleResize);
			if (animationFrame) {
				cancelAnimationFrame(animationFrame);
			}
		};
	});
</script>

<canvas bind:this={canvas}></canvas>
<div class="blur-overlay"></div>

<style>
	canvas {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		z-index: -1;
		pointer-events: none; /* Prevent canvas from blocking interactions */
	}
	.blur-overlay {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		backdrop-filter: blur(10px);
		background: rgba(57, 54, 70, 0.3);
		z-index: -1;
		pointer-events: none;
	}
	:global(body) {
		margin: 0;
		padding: 0;
		transition: background 0.3s ease;
	}
</style>
