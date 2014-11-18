

iSpy.Collections.ObjcClasses = Backbone.Collection.extend({

    initialize: function() {
        console.log("[Collections|ObjcClasses] initialize");
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
        for(index = 0; index < classList['classes'].length; ++index) {
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

