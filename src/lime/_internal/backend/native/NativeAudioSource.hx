package lime._internal.backend.native;

import haxe.Int64;
import haxe.MainLoop;
import haxe.Timer;

import lime.math.Vector4;
import lime.media.openal.AL;
import lime.media.openal.ALBuffer;
import lime.media.openal.ALSource;
import lime.media.openal.ext.EXT_float32;
import lime.media.vorbis.VorbisFile;
import lime.media.AudioManager;
import lime.media.AudioSource;
import lime.media.openal.AL;
import lime.utils.UInt8Array;

import sys.thread.Mutex;
import sys.thread.Thread;

@:access(lime.media.AudioBuffer)
class NativeAudioSource
{
	private static var STREAM_BUFFER_SIZE = 48000;
	private static var STREAM_NUM_BUFFERS = 3;
	private static var STREAM_TIMER_FREQUENCY = 100;

	private static var hasDirectChannelsExt:Null<Bool>;
	private static var hasALSoftLatencyExt:Null<Bool>;

	private static var activeAudioSources:Array<NativeAudioSource> = [];
	private static var processingMutex:Mutex = new Mutex();
	private static var processingThread:Thread;

	private var buffers:Array<ALBuffer>;
	private var bufferTimeBlocks:Array<Float>;

	private var completed:Bool;
	private var dataLength:Int;
	private var format:Int;
	private var handle:ALSource;
	private var loops:Int;
	private var parent:AudioSource;
	private var playing:Bool;
	private var buffering:Bool;
	private var streamEOF:Bool;
	private var position:Vector4;
	private var stream:Bool;
	private var streamTimer:Timer;
	private var everQueued:Bool;

	public function new(parent:AudioSource)
	{
		setupProcessingThread();

		this.parent = parent;
		this.buffering = false;
		this.streamEOF = false;
		position = new Vector4();
	}

	public function dispose():Void
	{
		if (handle != null)
		{
			unregisterSource(this);

			if (streamTimer != null)
			{
				streamTimer.stop();
				streamTimer = null;
			}

			if (playing && AL.getSourcei(handle, AL.SOURCE_STATE) == AL.PLAYING)
			{
				AL.sourceStop(handle);
			}
			
			playing = false;
			completed = true;

			AL.sourcei(handle, AL.BUFFER, null);
			AL.deleteSource(handle);

			if (buffers != null)
			{
				for (buffer in buffers)
				{
					AL.deleteBuffer(buffer);
				}
				buffers = null;
			}

			handle = null;
		}
	}

	public function init():Void
	{
		if (hasALSoftLatencyExt == null)
		{
			hasALSoftLatencyExt = AL.isExtensionPresent("AL_SOFT_source_latency");
		}

		if (hasDirectChannelsExt == null)
		{
			hasDirectChannelsExt = AL.isExtensionPresent("AL_SOFT_direct_channels")
				&& AL.isExtensionPresent("AL_SOFT_direct_channels_remix");
		}

		format = 0;
		streamEOF = false;

		switch (parent.buffer.dataFormat)
		{
			case S16:
				if (parent.buffer.channels == 1)
					format = AL.FORMAT_MONO16;
				else if (parent.buffer.channels == 2)
					format = AL.FORMAT_STEREO16;
			case F32:
				if (parent.buffer.channels == 1)
					format = AL.FORMAT_MONO_FLOAT32;
				else if (parent.buffer.channels == 2)
					format = AL.FORMAT_STEREO_FLOAT32;
		}

		if (parent.buffer.__srcVorbisFile != null || parent.buffer.__srcDecoder != null)
		{
			stream = true;
			everQueued = false;
			dataLength = parent.buffer.dataLength;

			buffers = new Array();
			bufferTimeBlocks = new Array();

			for (i in 0...STREAM_NUM_BUFFERS)
			{
				buffers.push(AL.createBuffer());
				bufferTimeBlocks.push(0);
			}

			handle = AL.createSource();
		}
		else
		{
			handle = AL.createSource();

			if (parent.buffer.__srcBuffer == null)
			{
				parent.buffer.__srcBuffer = AL.createBuffer();

				if (parent.buffer.__srcBuffer != null)
				{
					AL.bufferData(parent.buffer.__srcBuffer, format, parent.buffer.data, parent.buffer.data.length, parent.buffer.sampleRate);
				}
			}

			AL.sourcei(handle, AL.BUFFER, parent.buffer.__srcBuffer);
			dataLength = parent.buffer.data.length;
		}

		if (hasDirectChannelsExt)
		{
			AL.sourcei(handle, AL.DIRECT_CHANNELS_SOFT, AL.REMIX_UNMATCHED_SOFT);
		}

		registerSource(this);
	}

	public function play():Void
	{
		if (playing || handle == null) return;

		buffering = true;
		playing = true;

		if (stream)
		{
			var targetSeconds = parent.offset / 1000.0;
			var currentSeconds = 0.0;

			if (parent.buffer.__srcDecoder != null)
				currentSeconds = Int64.toInt(parent.buffer.__srcDecoder.tell()) / parent.buffer.sampleRate;
			else if (parent.buffer.__srcVorbisFile != null)
				currentSeconds = parent.buffer.__srcVorbisFile.timeTell();

			if (!everQueued && Math.abs(currentSeconds - targetSeconds) < 0.05)
			{
				everQueued = true;
				refillBuffers(buffers);
				AL.sourcePlay(handle);
			}
			else
			{
				everQueued = true;
				setCurrentTime(getCurrentTime());
			}

			if (streamTimer != null) streamTimer.stop();
			streamTimer = new Timer(STREAM_TIMER_FREQUENCY);
			streamTimer.run = streamTimer_onRun;
		}
		else
		{
			setCurrentTime(completed ? 0 : getCurrentTime());
		}
		
		buffering = false;
	}

	public function pause():Void
	{
		playing = false;

		if (handle == null) return;

		AL.sourcePause(handle);

		if (streamTimer != null)
		{
			streamTimer.stop();
			streamTimer = null;
		}
	}

	public function stop():Void
	{
		if (playing && handle != null && AL.getSourcei(handle, AL.SOURCE_STATE) == AL.PLAYING)
		{
			AL.sourceStop(handle);
		}

		playing = false;

		if (streamTimer != null)
		{
			streamTimer.stop();
			streamTimer = null;
		}

		setCurrentTime(0);
	}

	private function streamTimer_onRun():Void
	{
		refillBuffers();
	}

	private function readStreamBuffer(length:Int):UInt8Array
	{
		for (i in 0...STREAM_NUM_BUFFERS - 1)
		{
			bufferTimeBlocks[i] = bufferTimeBlocks[i + 1];
		}

		if (parent.buffer.__srcDecoder != null)
		{
			var decoder = parent.buffer.__srcDecoder;
			var currentFrame:Int64 = decoder.tell();
			bufferTimeBlocks[STREAM_NUM_BUFFERS - 1] = Int64.toInt(currentFrame) / parent.buffer.sampleRate;
			
			var bytesPerFrame = parent.buffer.channels * (parent.buffer.bitsPerSample / 8);
			var framesWanted = Std.int(length / bytesPerFrame);
			
			var decodedBytes:haxe.io.Bytes = decoder.decode(framesWanted, parent.buffer.dataFormat);
			
			if (decodedBytes == null || decodedBytes.length == 0) 
			{
				streamEOF = true;
				return null;
			}
			
			if (decodedBytes.length < length)
			{
				streamEOF = true;
			}

			return new UInt8Array(decodedBytes);
		}
		else if (parent.buffer.__srcVorbisFile != null)
		{
			var vorbisFile = parent.buffer.__srcVorbisFile;
			bufferTimeBlocks[STREAM_NUM_BUFFERS - 1] = vorbisFile.timeTell();

			var buffer = new UInt8Array(length);
			var read = 0, total = 0, readMax;

			while (total < length)
			{
				readMax = 4096;
				if (readMax > length - total) readMax = length - total;

				read = vorbisFile.read(buffer.buffer, total, readMax);

				if (read > 0) total += read;
				else break;
			}

			if (total == 0) 
			{
				streamEOF = true;
				return null;
			}
			if (total < length) 
			{
				streamEOF = true;
				return buffer.subarray(0, total);
			}

			return buffer;
		}

		streamEOF = true;
		return null;
	}

	private function refillBuffers(buffers:Array<ALBuffer> = null):Void
	{
		if (handle == null || parent == null || parent.buffer == null) return;
		if (parent.buffer.__srcDecoder == null && parent.buffer.__srcVorbisFile == null) return;

		if (buffers == null)
		{
			var buffersProcessed:Int = AL.getSourcei(handle, AL.BUFFERS_PROCESSED);
			if (buffersProcessed > 0)
			{
				buffers = AL.sourceUnqueueBuffers(handle, buffersProcessed);
			}
		}

		if (buffers != null)
		{
			var numBuffers = 0;
			var data;

			for (buffer in buffers)
			{
				data = readStreamBuffer(STREAM_BUFFER_SIZE);

				if (data != null && data.length > 0)
				{
					AL.bufferData(buffer, format, data, data.length, parent.buffer.sampleRate);
					numBuffers++;
				}
				else
				{
					break;
				}
			}

			if (numBuffers > 0)
			{
				AL.sourceQueueBuffers(handle, numBuffers, buffers);

				if (playing && handle != null && AL.getSourcei(handle, AL.SOURCE_STATE) == AL.STOPPED)
				{
					AL.sourcePlay(handle);
				}
			}
		}
	}

	// Event Handlers

	private function process():Void
	{
		if (!playing || buffering || AL.getSourcei(handle, AL.SOURCE_STATE) == AL.PLAYING) return;

		if (stream && !streamEOF)
		{
			MainLoop.runInMainThread(function():Void
			{
				if (playing && !buffering && handle != null)
				{
					refillBuffers();
					if (AL.getSourcei(handle, AL.SOURCE_STATE) != AL.PLAYING) 
					{
						AL.sourcePlay(handle);
					}
				}
			});
			return;
		}

		if (loops > 0)
		{
			playing = false;
			loops--;
			
			MainLoop.runInMainThread(function():Void
			{
				if (handle != null) {
					setCurrentTime(0);
					play();
				}
			});

			return;
		}

		if (!completed)
		{
			MainLoop.runInMainThread(function():Void
			{
				if (handle != null) stop();
				if (parent != null && parent.onComplete != null) parent.onComplete.dispatch();
			});
		}

		completed = true;
	}

	// Get & Set Methods

	public function getCurrentTime():Float
	{
		if (completed || (!stream && handle != null && AL.getSourcei(handle, AL.SOURCE_STATE) == AL.STOPPED && loops <= 0))
		{
			return getLength();
		}
		else if (handle != null)
		{
			if (stream)
			{
				var time = (bufferTimeBlocks[0] * 1000.0 + AL.getSourcef(handle, AL.SEC_OFFSET) * 1000.0) - parent.offset;
				return time < 0 ? 0 : time;
			}

			var time = (AL.getSourcef(handle, AL.SEC_OFFSET) * 1000.0) - parent.offset;
			return time < 0 ? 0 : time;
		}

		return 0;
	}

	public function setCurrentTime(value:Float):Float
	{
		if (handle != null)
		{
			var wasBuffering = buffering;
			buffering = true;

			if (stream)
			{
				AL.sourceStop(handle);

				if (parent != null && parent.buffer != null)
				{
					streamEOF = false;

					var targetSeconds = (value + parent.offset) / 1000.0;
					
					if (parent.buffer.__srcDecoder != null)
					{
						var targetFrame = Int64.ofInt(Std.int(targetSeconds * parent.buffer.sampleRate));
						parent.buffer.__srcDecoder.seek(targetFrame);
					}
					else if (parent.buffer.__srcVorbisFile != null)
					{
						parent.buffer.__srcVorbisFile.timeSeek(targetSeconds);
					}

					AL.sourceUnqueueBuffers(handle, STREAM_NUM_BUFFERS);
					refillBuffers(buffers);
				}

				if (playing) AL.sourcePlay(handle);
			}
			else
			{
				AL.sourceRewind(handle);
				AL.sourcef(handle, AL.SEC_OFFSET, (value + parent.offset) / 1000.0);

				if (playing) AL.sourcePlay(handle);
			}

			buffering = wasBuffering;
		}

		if (playing)
		{
			var timeRemaining = Std.int((getLength() - value) / getPitch());

			if (timeRemaining > 0) completed = false;
			else
			{
				playing = false;
				completed = true;
			}
		}

		return value;
	}

	public function getGain():Float
	{
		return handle != null ? AL.getSourcef(handle, AL.GAIN) : 1;
	}

	public function setGain(value:Float):Float
	{
		if (handle != null) AL.sourcef(handle, AL.GAIN, value);
		return value;
	}

	public function getLength():Float
	{
		var bytesPerFrame = parent.buffer.channels * (parent.buffer.bitsPerSample / 8.0);
		var totalFrames = dataLength / bytesPerFrame;
		return (totalFrames / parent.buffer.sampleRate) * 1000.0;
	}

	public function getLoops():Int
	{
		return loops;
	}

	public function setLoops(value:Int):Int
	{
		return loops = value;
	}

	public function getPitch():Float
	{
		return handle != null ? AL.getSourcef(handle, AL.PITCH) : 1;
	}

	public function setPitch(value:Float):Float
	{
		if (handle != null) AL.sourcef(handle, AL.PITCH, value);
		return value;
	}

	public function getPosition():Vector4
	{
		if (handle != null)
		{
			var value = AL.getSource3f(handle, AL.POSITION);
			position.x = value[0];
			position.y = value[1];
			position.z = value[2];
		}
		return position;
	}

	public function setPosition(value:Vector4):Vector4
	{
		position.x = value.x;
		position.y = value.y;
		position.z = value.z;
		position.w = value.w;

		if (handle != null)
		{
			AL.distanceModel(AL.NONE);
			AL.source3f(handle, AL.POSITION, position.x, position.y, position.z);
		}
		return position;
	}

	public function getLatency():Float
	{
		if (hasALSoftLatencyExt)
		{
			var offsets = AL.getSourcedvSOFT(handle, AL.SEC_OFFSET_LATENCY_SOFT, 2);
			if (offsets != null) return offsets[1] * 1000;
		}
		return 0;
	}

	// processing Thread Functions
	@:noCompletion private static function registerSource(source:NativeAudioSource):Void
	{
		processingMutex.acquire();
		if (!activeAudioSources.contains(source)) activeAudioSources.push(source);
		processingMutex.release();
	}

	@:noCompletion private static function unregisterSource(source:NativeAudioSource):Void
	{
		processingMutex.acquire();
		if (activeAudioSources.contains(source)) activeAudioSources.remove(source);
		processingMutex.release();
	}

	@:noCompletion private static function setupProcessingThread():Void
	{
		if (processingThread == null)
		{
			processingThread = Thread.create(function():Void
			{
				while (true)
				{
					processingMutex.acquire();
					for (activeAudioSource in activeAudioSources)
					{
						activeAudioSource.process();
					}
					processingMutex.release();
					Sys.sleep(0.01);
				}
			});
		}
	}
}