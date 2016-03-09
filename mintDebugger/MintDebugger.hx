package MintDebugger;

import openfl.display.Stage;

class MintDebugger
{
	private var _stage:Stage;

	public function new(stage:Stage):Void
	{
		_stage = stage;
		trace("MintDebugger inited");
	}
}
