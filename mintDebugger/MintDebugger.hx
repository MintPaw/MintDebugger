package mintDebugger;

import openfl.display.Stage;
import openfl.events.KeyboardEvent;
import openfl.ui.Keyboard;

class MintDebugger
{
	public static var debugKey:Int = Keyboard.F12;

	private var _stage:Stage;

	public function new(stage:Stage):Void {
		_stage = stage;
		stage.addEventListener(KeyboardEvent.KEY_UP, keyUp);
		trace("debugger loaded");
	}

	private function keyUp(e:KeyboardEvent):Void {

		if (e.keyCode == debugKey) {
			trace("debugger started");
		}
	}
}
