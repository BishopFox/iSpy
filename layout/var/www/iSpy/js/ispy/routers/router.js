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
        iSpyEvents.trigger('iosapp:index');
    },

    iosapp: function() {
        console.log("[Router] -> iOSApp | Index");
        iSpyEvents.trigger('iosapp:index');
    },

    classdump: function() {
        console.log("[Router] -> Class Dump | Index");
        iSpyEvents.trigger('classdump:index');
    },

    notfound: function() {
        console.log("[Router] -> Not Found | Index");
        iSpyEvents.trigger('notfound:index');
    },

});

