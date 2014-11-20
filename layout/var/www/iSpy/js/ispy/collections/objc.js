

iSpy.Collections.ObjcClasses = Backbone.Collection.extend({

    initialize: function() {
        //console.log("[Collections|ObjcClasses] initialize");
    },

    model: iSpy.Models.ObjcClass,

    comparator: function(model) {
        return model.get('name');
    },

    fetchAll: function() {
        iSpy.Events.on('sync:classList', this.addClassList, this);
        this.fetch();
    },

    addClassList: function(classList) {
        this.reset();
        for (var index = 0; index < classList['classes'].length; ++index) {
            this.add({name: classList['classes'][index]});
        }
        this.sort();
        this.trigger('classListChange');
    },

    /* Used by Backbone.sync */
    rpcRead: [
        {
            "messageType": "classList",
            "messageData": {}
        },
    ],

});


/* A list of methods owned by a class */
iSpy.Collections.ObjcMethods = Backbone.Collection.extend({

    initialize: function() {
        //console.log("[Collections|ObjcMethods] initialize");
    },

    model: iSpy.Models.ObjcMethod,

    comparator: function(model) {
        return model.get('name');
    },

});