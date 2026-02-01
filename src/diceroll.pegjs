{
	const defaultTarget = {
		type: "target",
		mod: "=",
		value: {
			type: "number",
			value: 1,
		},
	}

	const defaultExpression = {
		type: "number",
		value: 1,
	}
}

start = expr:Expression label:(.*) {
	expr.root = true;

	if (label) {
		expr.label = label.join("");
	}

	return expr;
}

InlineExpression = "[[" expr:Expression "]]" {
	return {
		type: "inline",
		expr,
	}
}

AnyRoll = roll:(ModGroupedRoll / FullRoll / Integer) _ label:Label? {
	if (label) {
		roll.label = label;
	}

	return roll;
}

ModGroupedRoll = group:GroupedRoll mods:(KeepMod / DropMod / SuccessMod / FailureMod)* _ label:Label? {
	if (mods.length > 0) {
		group.mods = (group.mods || []).concat(mods);
	}

	if (label) {
		group.label = label;
	}

	return group;
}

SuccessMod = mod:(">"/"<"/"=") expr:RollExpr {
	return {
		type: "success",
		mod,
		expr,
	}
}

FailureMod = "f" mod:(">"/"<"/"=")? expr:RollExpr {
	return {
		type: "failure",
		mod,
		expr,
	}
}

CriticalSuccessMod = "cs" mod:(">"/"<"/"=")? expr:RollExpr {
	return {
		type: "crit",
		mod,
		expr,
	}
}

CriticalFailureMod = "cf" mod:(">"/"<"/"=")? expr:RollExpr {
	return {
		type: "critfail",
		mod,
		expr,
	}
}

MatchTarget = mod:(">"/"<"/"=") expr:RollExpr {
	return {
		mod,
		expr,
	}
}

MatchMod = "m" count:"t"? min:Integer? target: MatchTarget? {
	const match = {
		type: "match",
		min: min || { type: "number", value: 2 },
		count: !!count,
	}

	if (target) {
		match.mod = target.mod;
		match.expr = target.expr;
	}

	return match;
}

KeepMod = "k" highlow:("l" / "h")? expr:RollExpr? {
	return {
		type: "keep",
		highlow,
		expr: expr || defaultExpression,
	}
}

DropMod = "d" highlow:("l" / "h")? expr:RollExpr? {
	return {
		type: "drop",
		highlow,
		expr: expr || defaultExpression,
	}
}

GroupedRoll = "{" _ head:(RollExpression) tail:(_ "," _ (RollExpression))* _ "}" {
	return {
		rolls: [head, ...tail.map((el) => el[3])],
		type: "group",
	}
}

RollExpression = head:RollOrExpression tail:(_ ("+") _ RollOrExpression)* {
	if (tail.length == 0) {
		return head;
	}

	const ops = tail
		.map((element) => ({
			type: "math",
			op: element[1],
			tail: element[3]
		}));

	return {
		head: head,
		type: "diceExpression",
		ops,
	};
}

RollOrExpression = FullRoll / Expression

FullRoll = roll:TargetedRoll _ label:Label? {
	if (label) {
		roll.label = label;
	}

	return roll;
}

TargetedRoll = head:RolledModRoll mods:(DropMod / KeepMod / SuccessMod / FailureMod / CriticalFailureMod / CriticalSuccessMod)* match:MatchMod? sort:(SortMod)? {
	const targets = mods.filter((mod) => ["success", "failure"].includes(mod.type));
	mods = mods.filter((mod) => !targets.includes(mod));

	head.mods = (head.mods || []).concat(mods);

	if (targets.length > 0) {
		head.targets = targets;
	}

	if (match) {
		head.match = match;
	}

	if (sort) {
		head.sort = sort;
	}

	return head;
}

SortMod = "s" dir:("a" / "d")? {
	if(dir == "d"){
		return {
			type: "sort",
			asc: false
		}
	}
	return {
		type: "sort",
		asc: true
	}
}

RolledModRoll = head:DiceRoll tail:(CompoundRoll / PenetrateRoll / ExplodeRoll / ReRollOnceMod / ReRollMod / DoubleSuccessMod)* {
	head.mods = (head.mods || []).concat(tail);
	return head;
}

DoubleSuccessMod = "ds" target:TargetMod? {
	return {
		type: "doublesuccess",
		target
	}
}

ExplodeRoll = "!" target:TargetMod? {
	return {
		type: "explode",
		target,
	}
}

CompoundRoll = "!!" target:TargetMod? {
	return {
		type: "compound",
		target,
	}
}

PenetrateRoll = "!p" target:TargetMod? {
	return {
		type: "penetrate",
		target,
	}
}

ReRollMod = "r" target:TargetMod? {
	target = target || defaultTarget;

	return {
		type: "reroll",
		target,
	}
}

ReRollOnceMod = "ro" target:TargetMod? {
	target = target || defaultTarget;

	return {
		type: "rerollOnce",
		target,
	}
}

TargetMod = mod:(">"/"<"/"=")? value:RollExpr {
	return {
		type: "target",
		mod,
		value,
	}
}

DiceRoll = head:RollExpr? "d" tail:(FateExpr / PercentExpr / RollExpr) {
	head = head ? head : { type: "number", value: 1 };

	return {
		die: tail,
		count: head,
		type: "die"
	};
}

FateExpr = ("F" / "f") {
	return {
		type: "fate",
	}
}

PercentExpr = ("%") {
	return {
		type: "number",
		value: "100",
	}
}

RollExpr = BracketExpression / RollQuery / Integer;

Expression = InlineExpression / AddSubExpression / BracketExpression;

BracketExpression = "(" expr:AddSubExpression ")" _ label:Label? {
	if (label) {
		expr.label = label;
	}

	return expr;
}

AddSubExpression = head:MultDivExpression tail:(_ ("+" / "-") _ MultDivExpression)* {
	if (tail.length == 0) {
		return head;
	}

	const ops = tail
		.map((element) => ({
			type: "math",
			op: element[1],
			tail: element[3],
		}));

	return {
		head,
		type: "expression",
		ops,
	};
}

MultDivExpression = head:ModExpoExpression tail:(_ ("*" / "/") _ ModExpoExpression)* {
	if (tail.length == 0) {
		return head;
	}

	const ops = tail
		.map((element) => ({
			type: "math",
			op: element[1],
			tail: element[3],
		}));

	return {
		head,
		type: "expression",
		ops,
	};
}

ModExpoExpression = head:FunctionOrRoll tail:(_ ("**" / "%") _ FunctionOrRoll)* {
	if (tail.length == 0) {
		return head;
	}

	const ops = tail
		.map((element) => ({
			type: "math",
			op: element[1],
			tail: element[3],
		}));

	return {
		head,
		type: "expression",
		ops,
	};
}

MathFunction = "floor" / "ceil" / "round" / "abs"

MathFnExpression = op:MathFunction _ "(" _ expr:AddSubExpression _ ")" {
	return {
		type: "mathfunction",
		op,
		expr
	};
}

RollQuery = "?{" prompt:QueryPrompt options:("|" QueryOption)* "}" {
	return {
		type: "rollquery",
		prompt: prompt,
		options: options.map((o) => o[1])
	}
}

QueryPrompt = chars:[^}|]+ { return chars.join(""); }

// QueryOption handles nested rollqueries by matching balanced braces
// This allows ?{Outer|?{Inner|default}} to work correctly
QueryOption = parts:QueryOptionPart+ { return parts.join(""); }

QueryOptionPart 
  = chars:[^{}|]+ { return chars.join(""); }
  / "{" inner:NestedContent "}" { return "{" + inner + "}"; }

NestedContent = parts:NestedPart* { return parts.join(""); }

NestedPart
  = chars:[^{}]+ { return chars.join(""); }
  / "{" inner:NestedContent "}" { return "{" + inner + "}"; }

// Note: AnyRoll comes BEFORE RollQuery intentionally. This ensures that when we have
// ?{...}d10, the DiceRoll rule (inside AnyRoll via FullRoll) matches the entire expression,
// rather than RollQuery matching just ?{...} and leaving "d10" as unconsumed input.
// Standalone rollqueries (like ?{value|5}) will still work since AnyRoll won't match them.
FunctionOrRoll = MathFnExpression / AnyRoll / RollQuery / BracketExpression

Integer "integer" = "-"? [0-9]+ {
	const num = parseInt(text(), 10);
	return {
		type: "number",
		value: num,
	}
}

Label = "[" label:([^\]]+) "]" {
	return label.join("")
}

_ "whitespace"
	= [ \t\n\r]*