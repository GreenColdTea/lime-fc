package lime.media.miniaudio;

#if (!lime_doc_gen || lime_miniaudio)
import haxe.Int64;

import lime.system.CFFIPointer;

class MAAudioBufferConfig
{
	public static function init(format:MAFormat, channels:Int, sampleRate:Int, sizeInFrames:Int64, pData:CFFIPointer):MAAudioBufferConfig
	{
		final config:MAAudioBufferConfig = new MAAudioBufferConfig();
		config.format = format;
		config.channels = channels;
		config.sampleRate = sampleRate;
		config.sizeInFrames = sizeInFrames;
		config.pData = pData;
		return config;
	}

	public var format:MAFormat;
	public var channels:Int;
	public var sampleRate:Int;
	public var sizeInFrames:Int64;
	public var pData:CFFIPointer;

	public function new():Void
	{
		format = UNKNOWN;
		channels = 0;
		sampleRate = 0;
		sizeInFrames = 0;
		pData = null;
	}

	public function toDynamicObject():Dynamic
	{
		return {
			format: format,
			channels: channels,
			sampleRate: sampleRate,
			sizeInFrames: {high: sizeInFrames.high, low: sizeInFrames.low},
			pData: pData
		}
	}
}
#end
