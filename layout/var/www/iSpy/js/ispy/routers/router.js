// iSpy Router
// ----------
iSpy.Router = Backbone.Router.extend({

    routes: {
        '': 'index',
        'iosapp': 'iosapp',
        'classdump': 'classdump',
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

    classdump: function() {
        console.log("[Router] -> Class Dump | Index");
        iSpy.Events.trigger('classdump:index');
    },

    notfound: function() {
        console.log("[Router] -> Not Found | Index");
        iSpy.Events.trigger('notfound:index');
    },

});
