package mintDebugger;

import openfl.display.*;
import openfl.text.*;
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
import hscript.*;

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
	private var _entryPath:Array<FieldEntry>;

	private var _uiRoot:Root;
	private var _list:ListView;
	private var _consoleInput:TextInput;
	private var _xmlUI:IDisplayObjectContainer;
	private var _pathButtons:Array<Button>;
	private var _objPathOver:String = "";

	private var _refreshLeft:Float = 0;
	private var _lastTime:Float = 0;
	private var _elapsed:Float = 0;

	private var _parser:Parser;
	private var _interp:MintInterp;

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

		if (!created) return;

		if (e.keyCode == Keyboard.ENTER && _consoleInput.text != "") {
			var s:String = _consoleInput.text;
			if (s.charAt(0) == "!") {
				var program = _parser.parseString(s.substr(1, s.length-2));
				_interp.execute(program);
				_consoleInput.text = "";
			}
		}
	}

	private function createDebugger():Void {
		created = true;
		_refreshLeft = 0;
		_lastTime = Timer.stamp();

		Toolkit.init();
		Toolkit.openFullscreen(function (root:Root) {_uiRoot = root;});
		_xmlUI = Toolkit.processXml(
				Xml.parse(ResourceManager.instance.getText("assets/layout.xml")));

		_uiRoot.style.backgroundAlpha = 0;
		_uiRoot.addChild(_xmlUI);

		_pathButtons = [_xmlUI.findChild("root", Button, true)];
		_pathButtons[0].onClick = clickedPath;
		_pathButtons[0].onMouseOver = overPath;
		_pathButtons[0].userData = 0;

		_consoleInput = _xmlUI.findChild("consoleInput", TextInput, true);
		_consoleInput.style.color = 0xFFFFFF;

		_list = _xmlUI.findChild("fields");
		_list.onClick = clickedField;
		setScope(_startPoint, "root");

		_parser = new Parser();
		_parser.allowTypes = true;
		_interp = new MintInterp();
		_interp.variables.set("root", _topEntry.value);

		_entryPath = [ _topEntry ];

		toggleDebugger();
	}

	private function setScope(
			field:Dynamic,
			name:String,
			parent:FieldEntry=null):Void
	{
		_topEntry = itFields(field, name);
		_topEntry.parent = parent;

		var newDS:ArrayDataSource = new ArrayDataSource();
		for (c in _topEntry.children) newDS.add(c.dsEntry);
		_list.dataSource = newDS;
	}

	private function itFields(field:Dynamic, name:String):FieldEntry {
		var topEntry:FieldEntry = toFieldEntry(name, field);

		if (Std.is(field, Array)) {
			for (i in 0...field.length)
				topEntry.children.push(toFieldEntry(cast i, field[i], topEntry));

			return topEntry;
		}

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
			_stage.addEventListener(MouseEvent.RIGHT_CLICK, rightClicked);
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
		ent.value = null;

		if (ent.parent.className == "Array") {
			ent.value = ent.parent.value[Std.parseInt(ent.name)];
		} else {
			ent.value = Reflect.field(ent.parent.value, ent.name);
		}

		var s:String = '${ent.name}:${ent.className}';
		if (ent.className == "Int" ||
				ent.className == "Float" ||
				ent.className == "Bool") {
			s += ' = ${ent.value}';
		} else if (ent.value == null) {
			s += " = null";
		} else if (ent.className == "Array") {
			s += ' = [${ent.value.length}]';
		} else {
			s += ' = {}';
		}

		ent.dsEntry.text = s;
	}

	private function clickedField(e:UIEvent):Void {
		var fieldName:String = _list.getItem(_list.selectedIndex).data.entry.name;
		var f:Dynamic = null;

		if (_topEntry.className == "Array") {
			f = _topEntry.value[Std.parseInt(fieldName)];
		} else {
			f = Reflect.field(_topEntry.value, fieldName);
		}

		if (f == null) return;
		if (primativeTypes.indexOf(Type.typeof(f)) != -1) return;
		trace('Moving into $fieldName');

		var pathBox = _xmlUI.findChild("pathBox");
		var b:Button = new Button();
		b.onClick = clickedPath;
		b.userData = _pathButtons.length;
		b.text = fieldName + ".";
		b.autoSize = true;
		_pathButtons.push(b);
		pathBox.addChild(b);

		setScope(f, fieldName, _topEntry);
		_entryPath.push(_topEntry);
	}

	private function clickedPath(e:UIEvent):Void {
		var buttonNum:Int = e.component.userData;

		if (buttonNum == _entryPath.length - 1) return;

		setScope(_entryPath[buttonNum].value, _entryPath[buttonNum].name);

		for (i in buttonNum+1..._pathButtons.length) {
			var rem = _pathButtons.pop();
			rem.parent.removeChild(rem);
			_entryPath.pop();
		}
	}

	private function overPath(e:UIEvent):Void {
		trace(e.component.text);
	}

	private function rightClicked(e:Event):Void {
		var itemPath:String = "";
		for (button in _pathButtons) itemPath += button.text;

		for (i in 0..._list.listSize) {
			if (_list.getItem(i).state == "over") {
				itemPath += _topEntry.children[i].name;
				break;
			}
		}

		_consoleInput.text += "!" + itemPath + " = ";
		_consoleInput.focus();
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

class MintInterp extends Interp {
	override function get(o:Dynamic, f:String):Dynamic {
		if(o == null) throw Expr.Error.EInvalidAccess(f);
		return Reflect.getProperty(o, f);
	}

	override function set(o:Dynamic, f:String, v:Dynamic):Dynamic {
		if(o == null) throw Expr.Error.EInvalidAccess(f);
		Reflect.setProperty(o, f, v);
		return v;
	}

}
