/**
* Objective-c Brush For SyntaxHighlighter
*
* @version
* 1.3.0
*
* @copyright
* Copyright (C) 2011 www.dreamingwish.com
*
*/
;(function()
{
    // CommonJS
    typeof(require) != 'undefined' ? SyntaxHighlighter = require('shCore').SyntaxHighlighter : null;

    function Brush()
    {
        var datatypes = 'char bool BOOL double float int long short id void ';

        var keywords = 'IBAction IBOutlet SEL YES NO readwrite readonly nonatomic '         +
                        'retain assign readonly getter setter nil NULL '                    +
                        'super self copy '                                                  +
                        'break case catch class const copy __finally __exception __try '    +
                        'const_cast continue private public protected __declspec '          +
                        'default delete deprecated dllexport dllimport do dynamic_cast '    +
                        'else enum explicit extern if for friend goto inline '              +
                        'mutable naked namespace new noinline noreturn nothrow '            +
                        'register reinterpret_cast return selectany '                       +
                        'sizeof static static_cast struct switch template this '            +
                        'thread throw true false try typedef typeid typename union '        +
                        'using uuid virtual volatile whcar_t while '

        //顺序很重要
        this.regexList = [
                        { regex: SyntaxHighlighter.regexLib.singleLineCComments,        css: 'comments' },              // one line comments
                        { regex: SyntaxHighlighter.regexLib.multiLineCComments,         css: 'comments' },              // multiline comments
                        { regex: SyntaxHighlighter.regexLib.doubleQuotedString,         css: 'color3' },                // double quoted strings
                        { regex: SyntaxHighlighter.regexLib.singleQuotedString,         css: 'color3' },                // single quoted strings
                        { regex: new RegExp('@\\w+\\b', 'g'),                           css: 'color2' },                // keyword pink 以@开头的可能是关键字
                        { regex: new RegExp('@', 'g'),                                  css: 'color3' },                // nsstring @"fsafds" red 以@开头的可能是nsstring
                        { regex: new RegExp('\.?\\b\\d+[a-z]?\\b', 'g'),                css: 'color6' },                // number blue 数字可以这样 23 23.4 23.4f 3l
                        { regex: new RegExp('^ *#.*', 'gm'),                            css: 'color5' },                // preprocessor brown
                        { regex: new RegExp('\\b(NS[A-Z]|UI[A-Z]|CG[A-Z])\\w+\\b', 'g'),css: 'color4' },                // builtInType purple
                        { regex: new RegExp(this.getKeywords(datatypes), 'gm'),		    css: 'color2' },		        // datatypes pink
                        { regex: new RegExp(this.getKeywords(keywords), 'gm'),          css: 'color2' },                // keyword pink
                        { regex: new RegExp('\\s+\\w+\\b\\s*(?=(:|\\]))', 'g'),         css: 'color7' },                // function call dark green 函数调用可能和三元操作符冲突
                        ];
    };

    Brush.prototype	= new SyntaxHighlighter.Highlighter();
    Brush.aliases	= ['objc', 'obj-c', 'objective-c'];

    SyntaxHighlighter.brushes.Objc = Brush;
    // CommonJS
    typeof(exports) != 'undefined' ? exports.Brush = Brush : null;
})();
