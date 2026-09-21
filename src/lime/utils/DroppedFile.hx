package lime.utils;

import haxe.io.Bytes;

import lime.app.Future;

#if (js && html5)
import js.html.File;
import js.html.FileReader;
import js.html.ProgressEvent;

import lime.app.Promise;
#end

class DroppedFile
{
	public var path(default, null):String;

	#if (js && html5)
	@:noCompletion
	private var file:File;
	#end

	@:noCompletion
	#if (js && html5)
	private function new(path:String, file:File):Void
	#else
	private function new(path:String):Void
	#end
	{
		this.path = path;
		#if (js && html5)
		this.file = file;
		#end
	}

	public function readFile():lime.app.Future<Bytes>
	{
		#if (js && html5)
		final promise:Promise<Bytes> = new Promise<Bytes>();

		final reader:FileReader = new FileReader();

		reader.onprogress = function(event:ProgressEvent):Void
		{
			if (event.lengthComputable)
			{
				promise.progress(event.loaded, event.total);
			}
		};

		reader.onerror = function(event:ProgressEvent):Void
		{
			promise.error(reader.error.message);
		};

		reader.onload = function(event:ProgressEvent):Void
		{
			promise.complete(Bytes.ofData(reader.result));
		};

		reader.readAsArrayBuffer(file);

		return promise.future;
		#else
		return Bytes.loadFromFile(path);
		#end
	}
}
