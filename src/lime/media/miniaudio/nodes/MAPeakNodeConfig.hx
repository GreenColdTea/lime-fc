package lime.media.miniaudio.nodes;

#if (!lime_doc_gen || lime_miniaudio)
class MAPeakNodeConfig
{
	public static function init(channels:Int, sampleRate:Int, gainDB:Float, q:Float, frequency:Float):MAPeakNodeConfig
	{
		final config:MAPeakNodeConfig = new MAPeakNodeConfig();
		config.channels = channels;
		config.sampleRate = sampleRate;
		config.gainDB = gainDB;
		config.q = q;
		config.frequency = frequency;
		return config;
	}

	public var channels:Int;
	public var sampleRate:Int;
	public var gainDB:Float;
	public var q:Float;
	public var frequency:Float;

	public function new():Void
	{
		channels = 0;
		sampleRate = 0;
		gainDB = 0;
		q = 0;
		frequency = 0;
	}

	public function toDynamicObject():Dynamic
	{
		return {
			channels: channels,
			sampleRate: sampleRate,
			gainDB: gainDB,
			q: q,
			frequency: frequency
		}
	}
}
#end
