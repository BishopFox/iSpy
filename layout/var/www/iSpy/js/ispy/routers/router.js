// iSpy Router
// ----------
iSpy.Router = Backbone.Router.extend({

    routes: {
        '': 'index',
        'iosapp': 'iosapp',
        'cycript': 'cycript',
        'classbrowser': 'classbrowser',
        'fourohfour': 'notfound',
    },

    index: function() {
        console.log("[Router] -> Index");
        iSpy.Events.trigger('iosapp:index');
    },

    iosapp: function() {
        console.log("[Router] -> iOSApp | Index");
        iSpy.Events.trigger('iosapp:index');
    },

    cycript: function() {
        console.log("[Router] -> Cycript | Index");
        iSpy.Events.trigger('cycript:index');
    },

    classbrowser: function() {
        console.log("[Router] -> Class Dump | Index");
        iSpy.Events.trigger('classbrowser:index');
    },

    notfound: function() {
        console.log("[Router] -> Not Found | Index");
        iSpy.Events.trigger('notfound:index');
    },

});

