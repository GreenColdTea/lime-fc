package lime.utils;

import haxe.io.Bytes;
import haxe.io.Path;

class DroppedFile
{
	public var fullName(default, null):String;
	public var directory(default, null):String;
	public var name(default, null):String;
	public var extension(default, null):String;
	public var content(default, null):Bytes;

	public function new(fileName:String, fileBytes:Bytes)
	{
		fullName = fileName;

		var pathObj = new Path(fileName);
		directory = pathObj.dir;
		name = pathObj.file;
		extension = pathObj.ext;

		content = fileBytes;
	}
}
