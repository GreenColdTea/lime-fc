package lime.media.miniaudio;

#if (!lime_doc_gen || lime_miniaudio)
import lime.system.CFFIPointer;

@:access(lime.system.CFFIPointer)
@:forward
abstract MADataSource(CFFIPointer) from CFFIPointer to CFFIPointer
{
	@:noCompletion @:op(A == B) private static inline function equalsPointer(a:MADataSource, b:MADataSource):Bool
	{
		return a.get() == b.get();
	}

	@:noCompletion @:op(A != B) private static inline function notEqualsPointer(a:MADataSource, b:MADataSource):Bool
	{
		return a.get() != b.get();
	}
}
#end
