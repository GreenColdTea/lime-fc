package lime.media.miniaudio;

#if (!lime_doc_gen || lime_miniaudio)
import lime.system.CFFIPointer;
import lime._internal.backend.native.NativeCFFI;

@:access(lime._internal.backend.native.NativeCFFI)
@:access(lime.system.CFFIPointer)
@:forward
abstract MANode(CFFIPointer) from CFFIPointer to CFFIPointer
{
	public function attach_output_bus(outputBusIndex:Int, pOtherNode:MANode, otherNodeInputBusIndex:Int):MAResult
	{
		#if (lime_cffi && lime_miniaudio && !macro)
		return NativeCFFI.lime_ma_node_attach_output_bus(this, outputBusIndex, pOtherNode, otherNodeInputBusIndex);
		#else
		return MAResult.ERROR;
		#end
	}

	public function detach_output_bus(outputBusIndex:Int):MAResult
	{
		#if (lime_cffi && lime_miniaudio && !macro)
		return NativeCFFI.lime_ma_node_detach_output_bus(this, outputBusIndex);
		#else
		return MAResult.ERROR;
		#end
	}

	public function detach_all_output_buses():MAResult
	{
		#if (lime_cffi && lime_miniaudio && !macro)
		return NativeCFFI.lime_ma_node_detach_all_output_buses(this);
		#else
		return MAResult.ERROR;
		#end
	}

	@:noCompletion @:op(A == B) private static inline function equalsPointer(a:MANode, b:MANode):Bool
	{
		return a.get() == b.get();
	}

	@:noCompletion @:op(A != B) private static inline function notEqualsPointer(a:MANode, b:MANode):Bool
	{
		return a.get() != b.get();
	}
}
#end
