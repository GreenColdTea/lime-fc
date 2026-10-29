package lime.media.miniaudio.nodes;

#if (!lime_doc_gen || lime_miniaudio)
class MANotchNodeConfig
{
	public static function init(channels:Int, sampleRate:Int, q:Float, frequency:Float):MANotchNodeConfig
	{
		final config:MANotchNodeConfig = new MANotchNodeConfig();
		config.channels = channels;
		config.sampleRate = sampleRate;
		config.q = q;
		config.frequency = frequency;
		return config;
	}

	public var channels:Int;
	public var sampleRate:Int;
	public var q:Float;
	public var frequency:Float;

	public function new():Void
	{
		channels = 0;
		sampleRate = 0;
		q = 0;
		frequency = 0;
	}

	public function toDynamicObject():Dynamic
	{
		return {
			channels: channels,
			sampleRate: sampleRate,
			q: q,
			frequency: frequency
		}
	}
}
#end
