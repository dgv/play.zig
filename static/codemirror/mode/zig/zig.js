// CodeMirror, copyright (c) by Marijn Haverbeke and others
// Distributed under an MIT license: https://codemirror.net/LICENSE

// prettier-ignore
(function(mod) {
  if (typeof exports == "object" && typeof module == "object") // CommonJS
    mod(require("../../lib/codemirror"));
  else if (typeof define == "function" && define.amd) // AMD
    define(["../../lib/codemirror"], mod);
  else // Plain browser env
    mod(CodeMirror);
})(function(CodeMirror) {
"use strict";

CodeMirror.defineMode("zig", function(config) {
  var indentUnit = config.indentUnit;

  var keywords = {
    "align":true, "allowzero":true, "and":true, "anyframe":true,
    "anytype":true, "asm":true, "async":true, "await":true,
    "break":true,
    "catch":true, "comptime":true, "const":true, "continue":true,
    "defer":true,
    "else":true, "enum":true, "errdefer":true, "error":true, "export":true,
    "extern":true,
    "fn":true, "for":true, "if":true, "inline":true,
    "linksection":true,
    "noalias":true, "nosuspend":true,
    "opaque":true, "or":true, "orelse":true,
    "packed":true, "pub":true,
    "resume":true, "return":true,
    "struct":true, "suspend":true, "switch":true,
    "test":true, "threadlocal":true, "try":true,
    "union":true, "unreachable":true, "usingnamespace":true,
    "var":true, "volatile":true,
    "while":true,
    // types
    "i8":true, "u8":true, "i16":true, "u16":true, "i32":true, "u32":true,
    "i64":true, "u64":true, "i128":true, "u128":true,
    "isize":true, "usize":true,
    "c_short":true, "c_ushort":true, "c_int":true, "c_uint":true,
    "c_long":true, "c_ulong":true, "c_longlong":true, "c_ulonglong":true,
    "c_longdouble":true, "c_void":true,
    "f16":true, "f32":true, "f64":true, "f128":true,
    "bool":true, "void":true, "noreturn":true, "type":true, "anyerror":true,
    "comptime_int":true, "comptime_float":true
  };

  var atoms = {
    "null":true, "false":true, "true":true, "undefined":true,
    // builtin functions... will live as atoms for now
    "@addWithOverflow":true, "@alignCast":true, "@alignOf":true, "@as":true,
    "@asyncCall":true, "@atomicLoad":true, "@atomicRmw":true, "@atomicStore":true,
    "@bitCast":true, "@bitOffsetOf":true, "@boolToInt":true, "@bitSizeOf":true,
    "@breakpoint":true, "@byteSwap":true, "@bitReverse":true, "@byteOffsetOf":true,
    "@call":true, "@cDefine":true, "@ceil":true, "@cImport":true, "@cInclude":true,
    "@cos":true, "@clz":true, "@cmpxchgStrong":true, "@cmpxchgWeak":true,
    "@compileError":true, "@compileLog":true, "@ctz":true, "@cUndef":true,
    "@divExact":true, "@divFloor":true, "@divTrunc":true,
    "@embedFile":true, "@enumToInt":true, "@errorName":true,
    "@errorReturnTrace":true, "@errorToInt":true, "@errSetCast":true,
    "@exp":true, "@exp2":true, "@export":true,
    "@fabs":true, "@fence":true, "@field":true, "@fieldParentPtr":true,
    "@floatCast":true, "@floatToInt":true, "@floor":true, "@frame":true,
    "@Frame":true, "@frameAddress":true, "@frameSize":true,
    "@hasDecl":true, "@hasField":true,
    "@import":true, "@intCast":true, "@intToEnum":true, "@intToError":true,
    "@intToFloat":true, "@intToPtr":true,
    "@log":true, "@log2":true, "@log10":true,
    "@memcpy":true, "@memset":true, "@mod":true, "@mulAdd":true,
    "@mulWithOverflow":true,
    "@panic":true, "@popCount":true, "@ptrCast":true, "@ptrToInt":true,
    "@reduce":true, "@rem":true, "@returnAddress":true, "@round":true,
    "@setAlignStack":true, "@setCold":true, "@setEvalBranchQuota":true,
    "@setFloatMode":true, "@setRuntimeSafety":true, "@shlExact":true,
    "@shlWithOverflow":true, "@shrExact":true, "@shuffle":true, "@sizeOf":true,
    "@splat":true, "@src":true, "@sqrt":true, "@sin":true, "@subWithOverflow":true,
    "@tagName":true, "@TagType":true, "@This":true, "@trunc":true, "@truncate":true,
    "@Type":true, "@typeInfo":true, "@typeName":true, "@TypeOf":true,
    "@wasmMemorySize":true, "@wasmMemoryGrow":true,
    "@unionInit":true,
  };

  var isOperatorChar = /[+\-*&^%:=<>!|\/]/;

  var curPunc;

  function tokenBase(stream, state) {
    var ch = stream.next();
    if (ch == '"' || ch == "'" || ch == "\\") {
      state.tokenize = tokenString(ch);
      return state.tokenize(stream, state);
    }
    if (/[\d\.]/.test(ch)) {
      if (ch == ".") {
        stream.match(/^[0-9]+([eE][\-+]?[0-9]+)?/);
      } else if (ch == "0") {
        stream.match(/^[xX][0-9a-fA-F]+/) || stream.match(/^0[0-7]+/);
      } else {
        stream.match(/^[0-9]*\.?[0-9]*([eE][\-+]?[0-9]+)?/);
      }
      return "number";
    }
    if (/[\[\]{}\(\),;\:\.]/.test(ch)) {
      curPunc = ch;
      return null;
    }
    if (ch == "/") {
      if (stream.eat("/")) {
        stream.skipToEnd();
        return "comment";
      }
    }
    if (isOperatorChar.test(ch)) {
      stream.eatWhile(isOperatorChar);
      return "operator";
    }
    stream.eatWhile(/[\w\$_\xa1-\uffff]/);
    var cur = stream.current();
    if (keywords.propertyIsEnumerable(cur)) {
      if (cur == "case" || cur == "default") curPunc = "case";
      return "keyword";
    }
    if (atoms.propertyIsEnumerable(cur)) return "atom";
    return "variable";
  }

  function tokenString(quote) {
    return function(stream, state) {
      if (quote == "\\") {
        var next;
        while ((next = stream.next()) != null) {
          if (next == '\n') break;
        }
        state.tokenize = tokenBase;
      } else {
        var escaped = false, next, end = false;
        while ((next = stream.next()) != null) {
          if (next == quote && !escaped) {end = true; break;}
          escaped = !escaped && next == "\\";
        }
        if (end || !escaped)
          state.tokenize = tokenBase;
      }
      return "string";
    };
  }

  function Context(indented, column, type, align, prev) {
    this.indented = indented;
    this.column = column;
    this.type = type;
    this.align = align;
    this.prev = prev;
  }

  function pushContext(state, col, type) {
    return state.context = new Context(state.indented, col, type, null, state.context);
  }

  function popContext(state) {
    if (!state.context.prev) return;
    var t = state.context.type;
    if (t == ")" || t == "]" || t == "}")
      state.indented = state.context.indented;
    return state.context = state.context.prev;
  }

  // Interface

  return {
    startState: function(basecolumn) {
      return {
        tokenize: null,
        context: new Context((basecolumn || 0) - indentUnit, 0, "top", false),
        indented: 0,
        startOfLine: true
      };
    },

    token: function(stream, state) {
      var ctx = state.context;
      if (stream.sol()) {
        if (ctx.align == null) ctx.align = false;
        state.indented = stream.indentation();
        state.startOfLine = true;
        if (ctx.type == "case") ctx.type = "}";
      }
      if (stream.eatSpace()) return null;
      curPunc = null;
      var style = (state.tokenize || tokenBase)(stream, state);
      if (style == "comment") return style;
      if (ctx.align == null) ctx.align = true;

      if (curPunc == "{") pushContext(state, stream.column(), "}");
      else if (curPunc == "[") pushContext(state, stream.column(), "]");
      else if (curPunc == "(") pushContext(state, stream.column(), ")");
      else if (curPunc == "case") ctx.type = "case";
      else if (curPunc == "}" && ctx.type == "}") popContext(state);
      else if (curPunc == ctx.type) popContext(state);
      state.startOfLine = false;
      return style;
    },

    indent: function(state, textAfter) {
      if (state.tokenize != tokenBase && state.tokenize != null) return CodeMirror.Pass;
      var ctx = state.context, firstChar = textAfter && textAfter.charAt(0);
      if (ctx.type == "case" && /^(?:case|default)\b/.test(textAfter)) {
        state.context.type = "}";
        return ctx.indented;
      }
      var closing = firstChar == ctx.type;
      if (ctx.align) return ctx.column + (closing ? 0 : 1);
      else return ctx.indented + (closing ? 0 : indentUnit);
    },

    electricChars: "{}):",
    closeBrackets: "()[]{}''\"\"",
    fold: "brace",
    lineComment: "//"
  };
});

CodeMirror.defineMIME("text/x-zig", "zig");

});
