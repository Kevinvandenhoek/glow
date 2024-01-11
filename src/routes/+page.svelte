<script lang="ts">
	import { onMount } from 'svelte';

	let bass = 0,
		mid = 0,
		treble = 0; // Frequency data variables

	async function loadShader(
		gl: WebGLRenderingContext,
		type: number,
		url: string
	): Promise<WebGLShader> {
		const response = await fetch(url);
		const source = await response.text();

		const shader = gl.createShader(type);
		if (!shader) throw new Error('Error creating shader.');

		gl.shaderSource(shader, source);
		gl.compileShader(shader);

		if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
			throw new Error('Error compiling shader: ' + gl.getShaderInfoLog(shader));
		}

		return shader;
	}

	async function initWebGL(
		canvas: HTMLCanvasElement
	): Promise<{ gl: WebGLRenderingContext; shaderProgram: WebGLProgram }> {
		const gl = canvas.getContext('webgl');
		if (!gl) throw new Error('Unable to initialize WebGL.');

		const vertexShader = await loadShader(gl, gl.VERTEX_SHADER, 'vertexShader.glsl');
		const fragmentShader = await loadShader(gl, gl.FRAGMENT_SHADER, 'fragmentShader.glsl');

		const shaderProgram = gl.createProgram();
		if (!shaderProgram) throw new Error('Error creating shader program.');

		gl.attachShader(shaderProgram, vertexShader);
		gl.attachShader(shaderProgram, fragmentShader);
		gl.linkProgram(shaderProgram);

		if (!gl.getProgramParameter(shaderProgram, gl.LINK_STATUS)) {
			throw new Error(
				'Unable to initialize the shader program: ' + gl.getProgramInfoLog(shaderProgram)
			);
		}

		return { gl, shaderProgram };
	}

	function calculateFrequencyBands(frequencyData: Uint8Array) {
		bass = frequencyData.slice(0, 10).reduce((a, b) => a + b, 0) / 10;
		mid = frequencyData.slice(10, 20).reduce((a, b) => a + b, 0) / 10;
		treble = frequencyData.slice(20, 30).reduce((a, b) => a + b, 0) / 10;
	}

	async function initAudioAndWebGL(canvas: HTMLCanvasElement) {
		const { gl, shaderProgram } = await initWebGL(canvas);

		const audioContext = new AudioContext();
		const audioElement = new Audio('track.mp3');
		const track = audioContext.createMediaElementSource(audioElement);
		const analyzer = audioContext.createAnalyser();
		track.connect(analyzer);
		analyzer.connect(audioContext.destination);
		audioElement.play();

		const frequencyData = new Uint8Array(analyzer.frequencyBinCount);

		function animate() {
			requestAnimationFrame(animate);
			analyzer.getByteFrequencyData(frequencyData);
			calculateFrequencyBands(frequencyData);

			const bassLocation = gl.getUniformLocation(shaderProgram, 'u_bass');
			const midLocation = gl.getUniformLocation(shaderProgram, 'u_mid');
			const trebleLocation = gl.getUniformLocation(shaderProgram, 'u_treble');

			gl.uniform1f(bassLocation, bass / 255);
			gl.uniform1f(midLocation, mid / 255);
			gl.uniform1f(trebleLocation, treble / 255);

			gl.clear(gl.COLOR_BUFFER_BIT);
			gl.useProgram(shaderProgram);

			// Setup to draw a square
			const positionBuffer = gl.createBuffer();
			gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
			const positions = [-1.0, 1.0, 1.0, 1.0, -1.0, -1.0, 1.0, -1.0];
			gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(positions), gl.STATIC_DRAW);
			const positionAttributeLocation = gl.getAttribLocation(shaderProgram, 'position');
			gl.enableVertexAttribArray(positionAttributeLocation);
			gl.vertexAttribPointer(positionAttributeLocation, 2, gl.FLOAT, false, 0, 0);

			gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
		}

		animate();
	}

	onMount(async () => {
		const canvas = document.getElementById('canvas') as HTMLCanvasElement;
		canvas.width = window.innerWidth;
		canvas.height = window.innerHeight;
	});

	async function onClick() {
		try {
			const canvas = document.getElementById('canvas') as HTMLCanvasElement;
			await initAudioAndWebGL(canvas);
		} catch (error) {
			console.error('Initialization failed:', error);
		}
	}
</script>

<main>
	<canvas id="canvas" on:click={onClick} />
</main>
