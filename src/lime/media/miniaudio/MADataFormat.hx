package lime.media.miniaudio;

#if (!lime_doc_gen || lime_miniaudio)
class MADataFormat
{
	public var format:MAFormat;
	public var channels:Int;
	public var sampleRate:Int;
	public var channelMap:Array<MAChannel>;

	public function new():Void {}
}
#end
