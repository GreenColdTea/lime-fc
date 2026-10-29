package lime.media.miniaudio.nodes;

#if (!lime_doc_gen || lime_miniaudio)
class MAHishelfNodeConfig
{
	public static function init(channels:Int, sampleRate:Int, gainDB:Float, shelfSlope:Float, frequency:Float):MAHishelfNodeConfig
	{
		final config:MAHishelfNodeConfig = new MAHishelfNodeConfig();
		config.channels = channels;
		config.sampleRate = sampleRate;
		config.gainDB = gainDB;
		config.shelfSlope = shelfSlope;
		config.frequency = frequency;
		return config;
	}

	public var channels:Int;
	public var sampleRate:Int;
	public var gainDB:Float;
	public var shelfSlope:Float;
	public var frequency:Float;

	public function new():Void
	{
		channels = 0;
		sampleRate = 0;
		gainDB = 0;
		shelfSlope = 0;
		frequency = 0;
	}

	public function toDynamicObject():Dynamic
	{
		return {
			channels: channels,
			sampleRate: sampleRate,
			gainDB: gainDB,
			shelfSlope: shelfSlope,
			frequency: frequency
		}
	}
}
#end
