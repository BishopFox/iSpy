iSpy.Router = Backbone.Router.extend({

    routes: {
        '': 'index',
        'appsummary': 'appsummary',
        'classdump': 'classdump',
        '*': 'notfound',
    },

    index: function() {
        console.log("[Router] -> Index");
        iSpyEvents.trigger('appsummary:page');
    },

    appsummary: function() {
        console.log("[Router] -> App Summary");
        iSpyEvents.trigger('appsummary:page');
    },

    classdump: function() {
        console.log("[Router] -> Class Dump");
        iSpyEvents.trigger('classdump:page');
    },

    notfound: function() {
        console.log("[Router] -> Not Found");
        iSpyEvents.trigger('notfound:page');
    },

});