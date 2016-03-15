package mintDebugger;

import openfl.display.*;
import openfl.events.*;
import openfl.ui.*;
import haxe.ui.toolkit.events.*;
import haxe.ui.toolkit.core.*;
import haxe.ui.toolkit.core.interfaces.*;
import haxe.ui.toolkit.data.*;
import haxe.ui.toolkit.containers.*;
import haxe.ui.toolkit.controls.*;
import haxe.ui.toolkit.resources.*;
import haxe.*;

class MintDebugger
{
	public static var debugKey:Int = Keyboard.F12;
	public static var refreshTime:Float = 1;
	public static var priorityNames:Array<String> = [];

	private static var created:Bool = false;
	private static var visible:Bool = false;

	private var primativeTypes:Array<Type.ValueType> = [
		Type.ValueType.TInt,
		Type.ValueType.TFloat,
		Type.ValueType.TBool
	];

	private var _stage:Stage;
	private var _topEntry:FieldEntry;

	private var _uiRoot:Root;
	private var _list:ListView;
	private var _xmlUI:IDisplayObjectContainer;

	private var _refreshLeft:Float = 0;
	private var _lastTime:Float = 0;
	private var _elapsed:Float = 0;

	private var _startPoint:Dynamic;

	public function new(stage:Stage, startPoint:Dynamic):Void {
		_stage = stage;
		_startPoint = startPoint;
		stage.addEventListener(KeyboardEvent.KEY_UP, keyUp);
		trace("MintDebugger ready.");
	}

	private function keyUp(e:KeyboardEvent):Void {
		if (e.keyCode == debugKey) {
			if (!created) createDebugger() else toggleDebugger();
		}
	}

	private function createDebugger():Void {
		created = true;
		_refreshLeft = refreshTime;
		_lastTime = Timer.stamp();

		Toolkit.init();
		Toolkit.openFullscreen(function (root:Root) {_uiRoot = root;});
		_xmlUI = Toolkit.processXml(
				Xml.parse(ResourceManager.instance.getText("assets/layout.xml")));

		_uiRoot.style.backgroundAlpha = 0;
		_uiRoot.addChild(_xmlUI);

		_list = _xmlUI.findChild("fields");
		setScope(_startPoint, "root");
		toggleDebugger();
	}

	private function setScope(field:Dynamic, name:String):Void {
		_topEntry = itFields(field, name);
		_list.dataSource.removeAll();
		for (c in _topEntry.children) _list.dataSource.add(c.dsEntry);

		trace('Found ${_topEntry.children.length}');
	}

	private function itFields(field:Dynamic, name:String):FieldEntry {
		var topEntry:FieldEntry = toFieldEntry(name, field);

		for (fname in Type.getInstanceFields(Type.getClass(topEntry.value))) {
			var f:Dynamic = Reflect.field(topEntry.value, fname);
			if (Type.typeof(f) == Type.ValueType.TFunction) continue;
			// if (Reflect.isFunction(f)) continue;

			var e:FieldEntry = toFieldEntry(fname, f, topEntry);
			topEntry.children.push(e);
		}

		topEntry.children.sort(function (f1, f2) { 
			return Reflect.compare(f1.name.toLowerCase(), f2.name.toLowerCase()); });

		var numMoved:Int = 0;
		for (i in 0...priorityNames.length) {
			var nameToFind:String = priorityNames[i];

			for (j in 0...topEntry.children.length) {
				if (topEntry.children[j].name == nameToFind) {
					var tmp = topEntry.children[j];
					topEntry.children[j] = topEntry.children[numMoved];
					topEntry.children[numMoved] = tmp;
					numMoved++;
					break;
				}
			}
		}

		return topEntry;
	}

	private function toFieldEntry(
			name:String,
			value:Dynamic,
			parent:Dynamic=null):FieldEntry
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
		ent.dsEntry.entry = ent;

		return ent;
	}

	public function toggleDebugger():Void {
		visible = !visible;
		_uiRoot.visible = visible;

		if (visible) {
			Mouse.show();
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

			for (ent in _topEntry.children) updateEntry(ent);
			cast(_list.dataSource, DataSource).dispatchEvent(new Event(Event.CHANGE));
		}
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
		} else if (ent.value == null) {
			s += " = null";
		} else {
			s += ' = {}';
		}

		ent.dsEntry.text = s;
	}

	private function clickedField(e:UIEvent):Void {
		var fieldName:String = _list.getItem(_list.selectedIndex).data.entry.name;
		var f:Dynamic = Reflect.field(_topEntry.value, fieldName);

		if (f == null) return;
		if (primativeTypes.indexOf(Type.typeof(f)) != -1) return;

		trace('Moving into $fieldName');
		setScope(f, fieldName);
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
