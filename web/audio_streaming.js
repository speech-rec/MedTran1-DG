/**
 * Native Web Audio Streaming for Real-time Speech-to-Text
 * Provides MediaRecorder-based audio streaming with proper format conversion
 */

class WebAudioStreamer {
    constructor() {
        this.mediaRecorder = null;
        this.audioStream = null;
        this.isRecording = false;
        this.onDataCallback = null;
        this.onErrorCallback = null;
        this.audioContext = null;
        this.processor = null;
        this.source = null;
        
        // Audio configuration for Deepgram compatibility
        this.config = {
            sampleRate: 16000,
            channels: 1,
            bitDepth: 16
        };
    }

    /**
     * Initialize audio streaming with microphone access
     */
    async initialize() {
        try {
            // Request microphone access
            this.audioStream = await navigator.mediaDevices.getUserMedia({
                audio: {
                    sampleRate: this.config.sampleRate,
                    channelCount: this.config.channels,
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true
                }
            });

            // Create AudioContext for real-time processing
            this.audioContext = new (window.AudioContext || window.webkitAudioContext)({
                sampleRate: this.config.sampleRate
            });

            this.source = this.audioContext.createMediaStreamSource(this.audioStream);
            
            console.log('🎤 Web audio streaming initialized successfully');
            return true;
        } catch (error) {
            console.error('❌ Failed to initialize web audio streaming:', error);
            if (this.onErrorCallback) {
                this.onErrorCallback('Failed to access microphone: ' + error.message);
            }
            return false;
        }
    }

    /**
     * Start real-time audio streaming
     */
    async startStreaming(onDataCallback, onErrorCallback) {
        if (!this.audioStream) {
            const initialized = await this.initialize();
            if (!initialized) return false;
        }

        this.onDataCallback = onDataCallback;
        this.onErrorCallback = onErrorCallback;

        try {
            // Method 1: Use MediaRecorder for chunked data (preferred for Deepgram)
            await this.startMediaRecorderStreaming();
            
            // Method 2: Use ScriptProcessorNode for real-time processing (fallback)
            // this.startScriptProcessorStreaming();
            
            this.isRecording = true;
            console.log('🌊 Web audio streaming started');
            return true;
        } catch (error) {
            console.error('❌ Failed to start streaming:', error);
            if (this.onErrorCallback) {
                this.onErrorCallback('Failed to start streaming: ' + error.message);
            }
            return false;
        }
    }

    /**
     * MediaRecorder-based streaming (recommended for Deepgram)
     */
    async startMediaRecorderStreaming() {
        // Configure MediaRecorder for optimal Deepgram compatibility
        const options = {
            mimeType: 'audio/webm;codecs=opus',
            audioBitsPerSecond: 16000
        };

        // Fallback MIME types if opus is not supported
        const mimeTypes = [
            'audio/webm;codecs=opus',
            'audio/webm',
            'audio/mp4',
            'audio/wav'
        ];

        let selectedMimeType = null;
        for (const mimeType of mimeTypes) {
            if (MediaRecorder.isTypeSupported(mimeType)) {
                selectedMimeType = mimeType;
                break;
            }
        }

        if (!selectedMimeType) {
            throw new Error('No supported audio MIME type found');
        }

        options.mimeType = selectedMimeType;
        console.log('🎵 Using MIME type:', selectedMimeType);

        this.mediaRecorder = new MediaRecorder(this.audioStream, options);

        // Handle data chunks
        this.mediaRecorder.ondataavailable = (event) => {
            if (event.data.size > 0 && this.onDataCallback) {
                // Convert Blob to ArrayBuffer for Flutter
                event.data.arrayBuffer().then(buffer => {
                    const uint8Array = new Uint8Array(buffer);
                    this.onDataCallback(uint8Array);
                });
            }
        };

        this.mediaRecorder.onerror = (event) => {
            console.error('❌ MediaRecorder error:', event.error);
            if (this.onErrorCallback) {
                this.onErrorCallback('MediaRecorder error: ' + event.error);
            }
        };

        // Start recording with small time slices for real-time streaming
        this.mediaRecorder.start(100); // 100ms chunks for real-time feel
    }

    /**
     * ScriptProcessorNode-based streaming (fallback method)
     */
    startScriptProcessorStreaming() {
        // Create a script processor for real-time audio processing
        const bufferSize = 4096;
        this.processor = this.audioContext.createScriptProcessor(bufferSize, 1, 1);

        this.processor.onaudioprocess = (event) => {
            if (!this.isRecording) return;

            const inputBuffer = event.inputBuffer;
            const inputData = inputBuffer.getChannelData(0);
            
            // Convert Float32Array to Int16Array (PCM 16-bit)
            const pcmData = this.float32ToInt16(inputData);
            
            if (this.onDataCallback) {
                this.onDataCallback(pcmData);
            }
        };

        // Connect the audio graph
        this.source.connect(this.processor);
        this.processor.connect(this.audioContext.destination);
    }

    /**
     * Convert Float32Array to Int16Array (PCM format)
     */
    float32ToInt16(float32Array) {
        const int16Array = new Int16Array(float32Array.length);
        for (let i = 0; i < float32Array.length; i++) {
            const sample = Math.max(-1, Math.min(1, float32Array[i]));
            int16Array[i] = sample < 0 ? sample * 0x8000 : sample * 0x7FFF;
        }
        return new Uint8List.fromList(Array.from(new Uint8Array(int16Array.buffer)));
    }

    /**
     * Stop audio streaming
     */
    stopStreaming() {
        this.isRecording = false;

        if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
            this.mediaRecorder.stop();
        }

        if (this.processor) {
            this.processor.disconnect();
            this.processor = null;
        }

        if (this.source) {
            this.source.disconnect();
        }

        if (this.audioContext && this.audioContext.state !== 'closed') {
            this.audioContext.close();
        }

        if (this.audioStream) {
            this.audioStream.getTracks().forEach(track => track.stop());
            this.audioStream = null;
        }

        console.log('🛑 Web audio streaming stopped');
    }

    /**
     * Get current audio stream status
     */
    getStatus() {
        return {
            isRecording: this.isRecording,
            hasAudioStream: !!this.audioStream,
            audioContextState: this.audioContext?.state || 'closed',
            mediaRecorderState: this.mediaRecorder?.state || 'inactive'
        };
    }
}

// Global instance for Flutter to access
window.webAudioStreamer = new WebAudioStreamer();

// Flutter JS Interop functions
window.initializeWebAudio = function() {
    console.log('🔄 [JS] initializeWebAudio called');
    return new Promise(async (resolve, reject) => {
        try {
            console.log('🔄 [JS] Starting web audio initialization...');
            const result = await window.webAudioStreamer.initialize();
            console.log('✅ [JS] Web audio initialization result:', result);
            resolve(result);
        } catch (error) {
            console.error('❌ [JS] Web audio initialization failed:', error);
            reject(error);
        }
    });
};

window.startWebAudioStreaming = function(onDataCallback, onErrorCallback) {
    console.log('🔄 [JS] startWebAudioStreaming called');
    return new Promise(async (resolve, reject) => {
        try {
            console.log('🔄 [JS] Starting web audio streaming...');
            const result = await window.webAudioStreamer.startStreaming(onDataCallback, onErrorCallback);
            console.log('✅ [JS] Web audio streaming result:', result);
            resolve(result);
        } catch (error) {
            console.error('❌ [JS] Web audio streaming failed:', error);
            reject(error);
        }
    });
};

window.stopWebAudioStreaming = function() {
    window.webAudioStreamer.stopStreaming();
};

window.getWebAudioStatus = function() {
    return window.webAudioStreamer.getStatus();
};

console.log('🚀 Web Audio Streaming JavaScript loaded successfully');