package mintDebugger;

import openfl.display.*;
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
	private var _accords:Array<Accordion>;
	private var _topEntry:FieldEntry;

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

		_accords = [];
		_uiRoot.style.backgroundAlpha = 0;
		// _uiRoot.addChild(accord);

		// var a:Accordion = new Accordion();
		// var b:Accordion = new Accordion();
		// var c:Button = new Button();
		// a.width = b.width = c.width = 400;
		// a.height = b.height = c.height = _stage.stageHeight;
		// a.text = b.text = c.text = "test";
		// _uiRoot.addChild(a);
		// a.addChild(b);
		// b.addChild(c);
		
		_topEntry = itFields(_stage, "stage", 0);
		trace("e's: " + _topEntry.children.length);
	}

	private function itFields(
			field:Dynamic,
			name:String,
			maxDepth:Int,
			currentDepth:Int=0):FieldEntry {

		var topEntry:FieldEntry = {
			type: Type.typeof(field),
			name: name,
			value: field,
			children: []
		};

		var noItTypes:Array<Type.ValueType> = [
			Type.ValueType.TInt, Type.ValueType.TFloat, Type.ValueType.TFunction,
			Type.ValueType.TNull];

		if (noItTypes.indexOf(topEntry.type) == -1)
		{
				for (f in Reflect.fields(topEntry.value))
				{
					var e:FieldEntry = {
						type: Type.typeof(Reflect.field(topEntry, f)),
						name: f,
						value: Reflect.field(topEntry, f),
						children: [],
						parent: topEntry
					};

					topEntry.children.push(e);

					if (currentDepth < maxDepth)
						itFields(e.value, e.name, maxDepth, currentDepth+1);
				}
		}

		return topEntry;
	}
}

typedef FieldEntry = {
	type:Type.ValueType,
	name:String,
	?parent:FieldEntry,
	children:Array<FieldEntry>,
	value:Dynamic
}
