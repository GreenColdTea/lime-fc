package lime.media.miniaudio.nodes;

#if (!lime_doc_gen || lime_miniaudio)
import lime.system.CFFIPointer;

class MABiquadNodeConfig
{
	public static function init(channels:Int, b0:Float, b1:Float, b2:Float, a0:Float, a1:Float, a2:Float):MABiquadNodeConfig
	{
		final config:MABiquadNodeConfig = new MABiquadNodeConfig();
		config.channels = channels;
		config.b0 = b0;
		config.b1 = b1;
		config.b2 = b2;
		config.a0 = a0;
		config.a1 = a1;
		config.a2 = a2;
		return config;
	}

	public var channels:Int;
	public var b0:Float;
	public var b1:Float;
	public var b2:Float;
	public var a0:Float;
	public var a1:Float;
	public var a2:Float;

	public function new():Void
	{
		channels = 0;
		b0 = 0;
		b1 = 0;
		b2 = 0;
		a0 = 0;
		a1 = 0;
		a2 = 0;
	}

	public function toDynamicObject():Dynamic
	{
		return {
			channels: channels,
			b0: b0,
			b1: b1,
			b2: b2,
			a0: a0,
			a1: a1,
			a2: a2
		}
	}
}
#end
