package mintDebugger;

import openfl.display.Stage;
import openfl.events.KeyboardEvent;
import openfl.ui.Keyboard;
import haxe.ui.toolkit.core.*;
import haxe.ui.toolkit.containers.*;
import haxe.ui.toolkit.controls.*;

class MintDebugger
{
	private static var created:Bool = false;
	public static var debugKey:Int = Keyboard.F12;

	private var _stage:Stage;
	private var _uiRoot:Root;

	public function new(stage:Stage):Void {
		_stage = stage;
		stage.addEventListener(KeyboardEvent.KEY_UP, keyUp);
		trace("MintDebugger ready.");
	}

	private function keyUp(e:KeyboardEvent):Void {

		if (e.keyCode == debugKey) {
			if (!created) {
				createDebugger();
				trace("MintDebugger created.");
			} else {
				trace("MintDebugger invoked.");
			}
		}
	}

	private function createDebugger():Void {
		created = true;
		Toolkit.init();
		Toolkit.openFullscreen(function (root:Root) {_uiRoot = root;});

		var accord:Accordion = new Accordion();
		// _uiRoot.alpha = 0;
		_uiRoot.addChild(accord);

		var b:Button = new Button();
		b.text = "Test";
		_uiRoot.addChild(b);
	}
}
