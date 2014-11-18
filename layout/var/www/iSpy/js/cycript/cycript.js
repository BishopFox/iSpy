/*
 * Cycript Console - Cross frame communication code
 */

/* Helper method from htlm5utils.js */
var addEvent = (function() {
    if (document.addEventListener) {
        return function(el, type, fn) {
            if (el && el.nodeName || el === window) {
                el.addEventListener(type, fn, false);
            } else if (el && el.length) {
                for (var i = 0; i < el.length; i++) {
                    addEvent(el[i], type, fn);
                }
            }
        };
    } else {
        return function(el, type, fn) {
            if (el && el.nodeName || el === window) {
                el.attachEvent('on' + type, function() {
                    return fn.call(el, window.event);
                });
            } else if (el && el.length) {
                for (var i = 0; i < el.length; i++) {
                    addEvent(el[i], type, fn);
                }
            }
        };
    }
})();


/* Simulate keystrokes: poor man's loader */
addEvent(window, "message", function(msg) {
    if (msg.origin !== window.location.origin) {
        console.log('[Cycript|PostMessage] Ignoring message from: ' + msg.origin);
    } else {
        console.log('[Cycript|PostMessage] Got message:');
        console.log(msg);
        console.log(window.butterfly);

    }
});

