package lime.media.miniaudio;

#if (!lime_doc_gen || lime_miniaudio)
import haxe.Int64;

class MASoundConfig
{
	public static inline function init():MASoundConfig
	{
		return new MASoundConfig();
	}

	public var pDataSource:MADataSource;
	public var pInitialAttachment:MANode;
	public var initialAttachmentInputBusIndex:Int;
	public var flags:Int;
	public var volumeSmoothTimeInPCMFrames:Int;
	public var initialSeekPointInPCMFrames:Int64;
	public var rangeBegInPCMFrames:Int64;
	public var rangeEndInPCMFrames:Null<Int64>;
	public var loopPointBegInPCMFrames:Int64;
	public var loopPointEndInPCMFrames:Null<Int64>;
	public var pNotifications:MASoundNotifications;

	public function new():Void
	{
		pDataSource = null;
		pInitialAttachment = null;
		initialAttachmentInputBusIndex = 0;
		flags = 0;
		volumeSmoothTimeInPCMFrames = 0;
		rangeBegInPCMFrames = 0;
		rangeEndInPCMFrames = null;
		loopPointBegInPCMFrames = 0;
		loopPointEndInPCMFrames = null;
		pNotifications = new MASoundNotifications();
	}

	public function toDynamicObject():Dynamic
	{
		return {
			pDataSource: pDataSource,
			pInitialAttachment: pInitialAttachment,
			initialAttachmentInputBusIndex: initialAttachmentInputBusIndex,
			flags: flags,
			volumeSmoothTimeInPCMFrames: volumeSmoothTimeInPCMFrames,
			initialSeekPointInPCMFrames: {
				high: initialSeekPointInPCMFrames.high,
				low: initialSeekPointInPCMFrames.low
			},
			rangeBegInPCMFrames: {high: rangeBegInPCMFrames.high, low: rangeBegInPCMFrames.low},
			rangeEndInPCMFrames: rangeEndInPCMFrames != null ? {high: rangeEndInPCMFrames.high, low: rangeEndInPCMFrames.low} : null,
			loopPointBegInPCMFrames: {high: loopPointBegInPCMFrames.high, low: loopPointBegInPCMFrames.low},
			loopPointEndInPCMFrames: loopPointEndInPCMFrames != null ? {high: loopPointEndInPCMFrames.high, low: loopPointEndInPCMFrames.low} : null,
			pNotifications: pNotifications
		}
	}
}
#end
