// iSpy Router
// ----------
iSpy.Router = Backbone.Router.extend({

    routes: {
        '': 'index',
        'iosapp': 'iosApp',
        'classbrowser': 'classBrowser',
        'displayclass/:className': 'displayClass',
        '*other': 'notfound',
    },

    index: function() {
        console.log("[Router] -> Index");
        iSpy.Events.trigger('router:index');
    },

    iosApp: function() {
        console.log("[Router] -> iOSApp");
        iSpy.Events.trigger('router:index');
    },

    classBrowser: function() {
        console.log("[Router] -> Class Browser");
        iSpy.Events.trigger('router:classbrowser');
    },

    displayClass: function(className) {
        console.log("[Router] -> Class Browser | displayClass: " + className);
        iSpy.Events.trigger('router:displayClass', className);
    },

    notfound: function(other) {
        console.log("[Router] -> Not Found");
        iSpy.Events.trigger('router:notfound', other);
    },

});

