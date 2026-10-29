package lime.media.miniaudio.nodes;

#if (!lime_doc_gen || lime_miniaudio)
import lime._internal.backend.native.NativeCFFI;

@:access(lime._internal.backend.native.NativeCFFI)
@:forward
abstract MANotchNode(MANode) from MANode to MANode
{
	public static function init(pNodeGraph:MANodeGraph, pConfig:MANotchNodeConfig):MANotchNode
	{
		#if (lime_cffi && lime_miniaudio && !macro)
		if (pConfig != null)
		{
			return NativeCFFI.lime_ma_notch_node_init(pNodeGraph, pConfig.toDynamicObject());
		}
		#end

		return null;
	}

	public function reinit(pConfig:MANotchNodeConfig)
	{
		#if (lime_cffi && lime_miniaudio && !macro)
		return pConfig != null ? NativeCFFI.lime_ma_notch_node_reinit(pConfig.toDynamicObject(), this) : MAResult.INVALID_ARGS;
		#else
		return MAResult.ERROR;
		#end
	}

	public function uninit():Void
	{
		#if (lime_cffi && lime_miniaudio && !macro)
		NativeCFFI.lime_ma_notch_node_uninit(this);
		#end
	}

	@:noCompletion @:op(A == B) private static inline function equalsPointer(a:MANotchNode, b:MANotchNode):Bool
	{
		return a.get() == b.get();
	}

	@:noCompletion @:op(A != B) private static inline function notEqualsPointer(a:MANotchNode, b:MANotchNode):Bool
	{
		return a.get() != b.get();
	}
}
#end
