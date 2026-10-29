package lime.media.miniaudio.nodes;

#if (!lime_doc_gen || lime_miniaudio)
class MADelayNodeConfig
{
	public static function init(channels:Int, sampleRate:Int, delayInFrames:Int, decay:Float):MADelayNodeConfig
	{
		final config:MADelayNodeConfig = new MADelayNodeConfig();
		config.channels = channels;
		config.sampleRate = sampleRate;
		config.delayInFrames = delayInFrames;
		config.decay = decay;
		return config;
	}

	public var channels:Int;
	public var sampleRate:Int;
	public var delayInFrames:Int;
	public var decay:Float;

	public function new():Void
	{
		channels = 0;
		sampleRate = 0;
		delayInFrames = 0;
		decay = 0;
	}

	public function toDynamicObject():Dynamic
	{
		return {
			channels: channels,
			sampleRate: sampleRate,
			delayInFrames: delayInFrames,
			decay: decay
		}
	}
}
#end
