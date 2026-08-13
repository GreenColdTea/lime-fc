package lime._internal.backend.native;

import haxe.Int64;
import haxe.Timer;

import lime.app.Application;
import lime.math.Vector4;
import lime.media.openal.AL;
import lime.media.openal.ALBuffer;
import lime.media.openal.ALSource;
import lime.media.openal.ext.EXT_float32;
import lime.media.vorbis.VorbisFile;
import lime.media.AudioManager;
import lime.media.AudioSource;
import lime.utils.UInt8Array;

@:access(lime.media.AudioBuffer)
class NativeAudioSource
{
	private static var STREAM_BUFFER_SIZE = 48000;
	private static var STREAM_NUM_BUFFERS = 3;
	private static var STREAM_TIMER_FREQUENCY = 100;

	private static var hasDirectChannelsExt:Null<Bool>;
	private static var hasALSoftLatencyExt:Null<Bool>;

	private var buffers:Array<ALBuffer>;
	private var bufferTimeBlocks:Array<Float>;
	private var completed:Bool;
	private var dataLength:Int;
	private var format:Int;
	private var handle:ALSource;
	private var length:Null<Float>;
	private var loops:Int;
	private var parent:AudioSource;
	private var playing:Bool;
	private var position:Vector4;
	private var stream:Bool;
	private var streamTimer:Timer;
	private var everQueued:Bool;

	public function new(parent:AudioSource)
	{
		this.parent = parent;

		position = new Vector4();
	}

	public function dispose():Void
	{
		if (handle != null)
		{
			if (Application.current != null && !stream)
			{
				if (Application.current.onUpdate.has(checkPlay))
				{
					Application.current.onUpdate.remove(checkPlay);
				}
			}

			stop();

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

		switch (parent.buffer.dataFormat)
		{
			case S16:
				if (parent.buffer.channels == 1)
				{
					format = AL.FORMAT_MONO16;
				}
				else if (parent.buffer.channels == 2)
				{
					format = AL.FORMAT_STEREO16;
				}
			case F32:
				if (parent.buffer.channels == 1)
				{
					format = AL.FORMAT_MONO_FLOAT32;
				}
				else if (parent.buffer.channels == 2)
				{
					format = AL.FORMAT_STEREO_FLOAT32;
				}
		}

		if (parent.buffer.__srcVorbisFile != null)
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

		if (!stream && !Application.current.onUpdate.has(checkPlay))
		{
			Application.current.onUpdate.add(checkPlay);
		}
	}

	public function play():Void
	{
		if (playing || handle == null)
		{
			return;
		}

		playing = true;

		if (stream)
		{
			var targetSeconds = parent.offset / 1000.0;

			// Skip the seek only if the VorbisFile (which may be reused from a prior
			// NativeAudioSource on this same buffer) is already at the target position.
			if (!everQueued && Math.abs(parent.buffer.__srcVorbisFile.timeTell() - targetSeconds) < 0.05)
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

			streamTimer = new Timer(STREAM_TIMER_FREQUENCY);
			streamTimer.run = streamTimer_onRun;
		}
		else
		{
			setCurrentTime(completed ? 0 : getCurrentTime());
		}
	}

	public function pause():Void
	{
		playing = false;

		if (handle == null)
		{
			return;
		}

		AL.sourcePause(handle);

		if (streamTimer != null)
		{
			streamTimer.stop();
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
		}

		setCurrentTime(0);
	}

	private function readVorbisFileBuffer(vorbisFile:VorbisFile, length:Int):UInt8Array
	{
		var buffer = new UInt8Array(length);
		var read = 0, total = 0, readMax;

		for (i in 0...STREAM_NUM_BUFFERS - 1)
		{
			bufferTimeBlocks[i] = bufferTimeBlocks[i + 1];
		}
		bufferTimeBlocks[STREAM_NUM_BUFFERS - 1] = vorbisFile.timeTell();

		while (total < length)
		{
			readMax = 4096;

			if (readMax > length - total)
			{
				readMax = length - total;
			}

			read = vorbisFile.read(buffer.buffer, total, readMax);

			if (read > 0)
			{
				total += read;
			}
			else
			{
				break;
			}
		}

		return buffer;
	}

	private function refillBuffers(buffers:Array<ALBuffer> = null):Void
	{
		var vorbisFile = null;
		var position = 0;

		if (buffers == null)
		{
			var buffersProcessed:Int = AL.getSourcei(handle, AL.BUFFERS_PROCESSED);

			if (buffersProcessed > 0)
			{
				vorbisFile = parent.buffer.__srcVorbisFile;
				position = Int64.toInt(vorbisFile.pcmTell());

				if (position < dataLength)
				{
					buffers = AL.sourceUnqueueBuffers(handle, buffersProcessed);
				}
			}
		}

		if (buffers != null)
		{
			if (vorbisFile == null)
			{
				vorbisFile = parent.buffer.__srcVorbisFile;
				position = Int64.toInt(vorbisFile.pcmTell());
			}

			var numBuffers = 0;
			var data;

			for (buffer in buffers)
			{
				if (dataLength - position >= STREAM_BUFFER_SIZE)
				{
					data = readVorbisFileBuffer(vorbisFile, STREAM_BUFFER_SIZE);
					AL.bufferData(buffer, format, data, data.length, parent.buffer.sampleRate);
					position += STREAM_BUFFER_SIZE;
					numBuffers++;
				}
				else if (position < dataLength)
				{
					data = readVorbisFileBuffer(vorbisFile, dataLength - position);
					AL.bufferData(buffer, format, data, data.length, parent.buffer.sampleRate);
					numBuffers++;
					break;
				}
			}

			AL.sourceQueueBuffers(handle, numBuffers, buffers);

			// OpenAL can unexpectedly stop playback if the buffers run out
			// of data, which typically happens if an operation (such as
			// resizing a window) freezes the main thread.
			// If AL is supposed to be playing but isn't, restart it here.
			if (playing && handle != null && AL.getSourcei(handle, AL.SOURCE_STATE) == AL.STOPPED)
			{
				AL.sourcePlay(handle);
			}
		}
	}

	// Event Handlers

	private function streamTimer_onRun():Void
	{
		refillBuffers();
	}

	private function checkPlay(_):Void
	{
		if (AL.getSourcei(handle, AL.SOURCE_STATE) == AL.PLAYING)
		{
			return;
		}

		if (loops > 0)
		{
			playing = false;
			loops--;
			setCurrentTime(0);
			play();
			return;
		}

		if (!completed)
		{
			stop();
			parent.onComplete.dispatch();
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
			if (stream)
			{
				AL.sourceStop(handle);

				parent.buffer.__srcVorbisFile.timeSeek((value + parent.offset) / 1000.0);
				AL.sourceUnqueueBuffers(handle, STREAM_NUM_BUFFERS);
				refillBuffers(buffers);

				if (playing)
					AL.sourcePlay(handle);
			}
			else
			{
				AL.sourceRewind(handle);

				AL.sourcef(handle, AL.SEC_OFFSET, (value + parent.offset) / 1000.0);

				if (playing)
					AL.sourcePlay(handle);
			}
		}

		if (playing)
		{
			var timeRemaining = Std.int((getLength() - value) / getPitch());

			if (timeRemaining > 0)
			{
				completed = false;
			}
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
		if (handle != null)
		{
			return AL.getSourcef(handle, AL.GAIN);
		}
		else
		{
			return 1;
		}
	}

	public function setGain(value:Float):Float
	{
		if (handle != null)
		{
			AL.sourcef(handle, AL.GAIN, value);
		}

		return value;
	}

	public function getLength():Float
	{
		if (length != null)
		{
			return length;
		}

		var bytesPerFrame = parent.buffer.channels * (parent.buffer.bitsPerSample / 8.0);

		var totalFrames = dataLength / bytesPerFrame;

		return ((totalFrames / parent.buffer.sampleRate) * 1000.0) - parent.offset;
	}

	public function setLength(value:Float):Float
	{
		return length = value;
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
		if (handle != null)
		{
			return AL.getSourcef(handle, AL.PITCH);
		}
		else
		{
			return 1;
		}
	}

	public function setPitch(value:Float):Float
	{
		if (handle != null)
		{
			AL.sourcef(handle, AL.PITCH, value);
		}

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

			if (offsets != null)
			{
				return offsets[1] * 1000;
			}
		}

		return 0;
	}
}
