package lime.media.miniaudio.nodes;

#if (!lime_doc_gen || lime_miniaudio)
class MALpfNodeConfig
{
	public static function init(channels:Int, sampleRate:Int, cutoffFrequency:Float, order:Int):MALpfNodeConfig
	{
		final config:MALpfNodeConfig = new MALpfNodeConfig();
		config.channels = channels;
		config.sampleRate = sampleRate;
		config.cutoffFrequency = cutoffFrequency;
		config.order = order;
		return config;
	}

	public var channels:Int;
	public var sampleRate:Int;
	public var cutoffFrequency:Float;
	public var order:Int;

	public function new():Void
	{
		channels = 0;
		sampleRate = 0;
		cutoffFrequency = 0;
		order = 0;
	}

	public function toDynamicObject():Dynamic
	{
		return {
			channels: channels,
			sampleRate: sampleRate,
			cutoffFrequency: cutoffFrequency,
			order: order
		}
	}
}
#end
