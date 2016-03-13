package mintDebugger;

import openfl.display.*;
import openfl.events.*;
import openfl.ui.*;
import haxe.ui.toolkit.core.*;
import haxe.ui.toolkit.data.*;
import haxe.ui.toolkit.containers.*;
import haxe.ui.toolkit.controls.*;
import haxe.*;

class MintDebugger
{
	public static var debugKey:Int = Keyboard.F12;
	public static var refreshTime:Float = 1;

	private static var created:Bool = false;
	private static var visible:Bool = false;

	private var _stage:Stage;
	private var _uiRoot:Root;
	private var _list:ListView;
	private var _topEntry:FieldEntry;

	private var _refreshLeft:Float = 0;
	private var _lastTime:Float = 0;
	private var _elapsed:Float = 0;

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
		_refreshLeft = refreshTime;
		_lastTime = Timer.stamp();

		Toolkit.init();
		Toolkit.openFullscreen(function (root:Root) {_uiRoot = root;});
		_uiRoot.style.backgroundAlpha = 0;

		_topEntry = itFields(_stage, "stage", 0);

		_list = new ListView();
		_list.width = 300;
		_list.height = _stage.stageHeight * 0.9;
		_list.x = 20;
		_list.y = _stage.stageHeight/2 - _list.height/2;
		_uiRoot.addChild(_list);

		trace('Found ${_topEntry.children.length}');
		for (c in _topEntry.children) {
			_list.dataSource.add(c.dsEntry);
		}

		toggleDebugger();
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
		//TODO: Fix Neko being retarded
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
			dsEntry: {text: ""},
			value: value
		};

		return ent;
	}

	public function toggleDebugger():Void {
		visible = !visible;
		if (visible) {
			_stage.addEventListener(Event.ENTER_FRAME, update);
		} else {
			_stage.removeEventListener(Event.ENTER_FRAME, update);
		}
	}

	public function update(e:Event):Void {
		_elapsed = Timer.stamp() - _lastTime;
		_lastTime = Timer.stamp();

		_refreshLeft -= _elapsed;
		if (_refreshLeft <= 0) {
			_refreshLeft = refreshTime;
			updateFields();
		}
	}

	public function updateFields() {
		for (ent in _topEntry.children) updateEntry(ent);

		cast(_list.dataSource, DataSource).dispatchEvent(
				new Event(Event.CHANGE, true, true));
	}

	public function updateEntry(ent:FieldEntry):Void {
		ent.value = Reflect.field(ent.parent.value, ent.name);

		var s:String = '${ent.name}:${ent.className}';
		if (ent.className == "Int" ||
				ent.className == "Float" ||
				ent.className == "Bool") {
			s += ' = ${ent.value}';
		} else if (ent.className == "Array") {
			s += " = []";
		} else {
			s += ' = {}';
		}

		ent.dsEntry.text = s;
	}
}

typedef FieldEntry = {
	className:String,
	name:String,
	?dsEntry:Dynamic,
	?parent:FieldEntry,
	children:Array<FieldEntry>,
	value:Dynamic
}
