<script lang="ts">
	import { onMount } from 'svelte';

	$: isPlaying = false;
	$: bass = 0;
	$: mid = 0;
	$: treble = 0;

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

	function calculateFrequencyBands(frequencyData: Uint8Array, sampleRate: number, fftSize: number) {
		const frequencyStep = sampleRate / fftSize; // Frequency represented by each index

		// Define frequency ranges
		const bassRange = { min: 20, max: 250 };
		const midRange = { min: 250, max: 4000 };
		const trebleRange = { min: 4000, max: 20000 };

		// Helper function to calculate average amplitude in a frequency range
		function averageInRange(range: { min: number; max: number }) {
			const start = Math.floor(range.min / frequencyStep);
			const end = Math.ceil(range.max / frequencyStep);
			const count = end - start;
			const sum = frequencyData.slice(start, end).reduce((a, b) => a + b, 0);
			return sum / count;
		}

		// Calculate average amplitude for each range
		bass = averageInRange(bassRange);
		mid = averageInRange(midRange) * 2;
		treble = averageInRange(trebleRange) * 10;
	}

	async function initAudioAndWebGL(canvas: HTMLCanvasElement) {
		const { gl, shaderProgram } = await initWebGL(canvas);

		const audioContext = new AudioContext();
		const audioElement = new Audio('track.mp3');
		const track = audioContext.createMediaElementSource(audioElement);
		const analyzer = audioContext.createAnalyser();
		analyzer.fftSize = 2048; // Example FFT size
		track.connect(analyzer);
		analyzer.connect(audioContext.destination);
		audioElement.play();

		const frequencyData = new Uint8Array(analyzer.frequencyBinCount);
		analyzer.getByteFrequencyData(frequencyData);

		function animate() {
			requestAnimationFrame(animate);
			analyzer.getByteFrequencyData(frequencyData);
			calculateFrequencyBands(frequencyData, audioContext.sampleRate, analyzer.fftSize);

			const bassLocation = gl.getUniformLocation(shaderProgram, 'u_bass');
			const midLocation = gl.getUniformLocation(shaderProgram, 'u_mid');
			const trebleLocation = gl.getUniformLocation(shaderProgram, 'u_treble');

			gl.uniform1f(bassLocation, bass / 255);
			gl.uniform1f(midLocation, mid / 255);
			gl.uniform1f(trebleLocation, treble / 255);

			const resolutionLocation = gl.getUniformLocation(shaderProgram, 'u_resolution');
			gl.uniform2f(resolutionLocation, canvas.width, canvas.height);

			const timeLocation = gl.getUniformLocation(shaderProgram, 'u_time');
			gl.uniform1f(timeLocation, performance.now() * 0.001); // Converts time to seconds

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
		if (isPlaying) return;
		isPlaying = true;

		try {
			const canvas = document.getElementById('canvas') as HTMLCanvasElement;
			await initAudioAndWebGL(canvas);
		} catch (error) {
			console.error('Initialization failed:', error);
		}
	}
</script>

<main>
	<div style="position:absolute">
		<canvas id="canvas" on:click={onClick} />
	</div>
	<div style="position:absolute">
		<p>{bass / 255}</p>
		<p>{mid / 255}</p>
		<p>{treble / 255}</p>
	</div>
</main>
