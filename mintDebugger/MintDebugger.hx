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

		// var s:Dynamic = _stage;
		// trace(_stage.stageWidth, Reflect.getProperty(s, "stageWidth"));
		_topEntry = itFields(_stage, "stage", 0);

		for (c in _topEntry.children) {
			var s:String = "";
			s += c.name;
			s += " (" + c.className + ")";
			s += " = " + c.value;
			trace(s);
		}

		// var a:Accordion = new Accordion();
		// a.width = 400;
		// a.height = 400;
		// a.text = d.toString();
		// _accords.push(a);
		// _uiRoot.addChild(a);
	}

	private function itFields(
			field:Dynamic,
			name:String,
			maxDepth:Int,
			currentDepth:Int=0):FieldEntry {

		var topEntry:FieldEntry = toFieldEntry(name, field);

		for (fname in Type.getInstanceFields(Type.getClass(topEntry.value))) {
			var f:Dynamic = Reflect.field(topEntry.value, fname);
			if (Type.typeof(f) == Type.ValueType.TFunction) continue;
			// if (Reflect.isFunction(f)) continue;

			var e:FieldEntry = toFieldEntry(fname, f, topEntry);
			topEntry.children.push(e);

		var noItClasses:Array<String> = ["Int", "Bool", "Float"];
			if (noItClasses.indexOf(topEntry.className) == -1) {
				if (currentDepth < maxDepth)
					itFields(e.value, e.name, maxDepth, currentDepth+1);
			}
		}

		return topEntry;
	}

	private function toFieldEntry(
			name:String,
			value:Dynamic,
			parent=null):FieldEntry
	{
		//TODO: Fix Neko
		var className:String = "?";

		var t = Type.typeof(value);
		if (t == Type.ValueType.TInt) className = "Int";
		else if (t == Type.ValueType.TFloat) className = "Float";
		else if (t == Type.ValueType.TBool) className = "Bool";
		else className = Type.getClassName(Type.getClass(value));

		var ent:FieldEntry = {
			className: className,
			name: name,
			parent: parent,
			children: [],
			value: value
		};

		return ent;
	}
}

typedef FieldEntry = {
	className:String,
	name:String,
	?parent:FieldEntry,
	children:Array<FieldEntry>,
	value:Dynamic
}
