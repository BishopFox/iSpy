(function($){
   $.HexDump = function(el, buffer, options){
        // To avoid scope issues, use 'base' instead of 'this'
        // to reference this class from internal events and functions.
        var base = this;
        
        // Access to jQuery and DOM versions of element
        base.$el = $(el);
        base.el = el;
        
        // Add a reverse reference to the DOM object
        base.$el.data("HexDump", base);
        
        base.init = function(){
            base.buffer = buffer;
            base.options = $.extend({},$.HexDump.defaultOptions, options);
            // Put your initialization code here - normalize hex data
            var dumpAscii = function (intVal) {
                if(intVal < 0x20 || intVal > 0x7e)
                    return '.';
                return String.fromCharCode(intVal);
            };

            var handleDown = function() {
                var els = $('.hd' + $(this).attr('offset'));
                var wasSelected = $(this).hasClass('ui-selecting'); 
                $('.ui-selecting').removeClass('ui-selecting');
                if(!wasSelected) { 
                    els.addClass('ui-origin ui-selecting');
                    base.highlightMouseDown = true;
                }
            };

            var handleEnter = function(e) {
                if(base.highlightMouseDown) {
                    var els = $('.hd' + $(this).attr('offset'));
                    $('.ui-selecting').removeClass('ui-selecting');
                    els.addClass('ui-selecting');
                    $('.ui-origin').addClass('ui-selecting');
                    if(els.prevAll('.ui-origin').length > 0) {
                        els.prevUntil('.ui-origin').addClass('ui-selecting');
                    }
                    else if (els.nextAll('.ui-origin').length > 0)
                        els.nextUntil('.ui-origin').addClass('ui-selecting');
                }
            };

            var handleUp = function() { 
                base.highlightMouseDown = false;
                $('.ui-origin').removeClass('ui-origin');
            };

            base.highlightMouseDown = false;

           // Create div to hold hex dump
            var rowNumbers = $('<div/>')
                                .addClass('rowNumbers');
            var hexDump = $('<div/>')
                                .addClass('hexDump');
            var asciiDump = $('<div/>')
                                .addClass('asciiDump');

            $.each(base.buffer, function(i,v) {
                if((i % base.options.byteWidth) == 0) {
                    $('<div/>')
                        .text(base.options.byteWidth * (i/base.options.byteWidth))
                        .addClass('rowNumber')
                        .appendTo(rowNumbers);
                }

                $('<span/>')
                    .addClass('hexCell')
                    .addClass('hd'+i)
                    .addClass((i+1)%(base.options.byteGroup) == 0 ? 'spacer' : i%(base.options.byteWidth) == 0 ? 'end' : '')
                    .attr('offset', i)
                    .text(v.toString(16).length == 2 ? v.toString(16) : "0"+v.toString(16))
                    .mouseenter(handleEnter)
                    .mousedown(handleDown)
                    .mouseup(handleUp)
                    .appendTo(hexDump);

                $('<span/>')
                    .addClass('asciiCell')
                    .addClass('hd'+i)
                    .addClass(i%(base.options.byteWidth) == 0 ? 'end' : '')
                    .attr('offset', i)
                    .text(dumpAscii(v))
                    .mouseenter(handleEnter)
                    .mousedown(handleDown)
                    .mouseup(handleUp)
                    .appendTo(asciiDump);
            });

            base.$el.append(rowNumbers)
                    .append(hexDump)
                    .append(asciiDump)
                    .append($("<div/>").addClass('end'));
        };
        
        // Sample Function, Uncomment to use
        // base.functionName = function(paramaters){
        // 
        // };
        
        // Run initializer
        base.init();
    };
    
    $.HexDump.defaultOptions = {
        byteWidth: 16,
        byteGroup: 4
    };
    
    $.fn.hexDump = function(buffer, options){
        return this.each(function(){
            (new $.HexDump(this, buffer, options));
        });
    };
    
    // This function breaks the chain, but returns
    // the HexDump if it has been attached to the object.
    $.fn.getHexDump = function(){
        this.data("HexDump");
    };
    
})(jQuery);
