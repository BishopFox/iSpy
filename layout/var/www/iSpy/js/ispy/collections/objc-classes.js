

iSpy.Collections.ObjcClasses = Backbone.Collection.extend({

    initialize: function() {
        console.log("[Collections|ObjcClasses] initialize");
        iSpy.Events.on('sync:classList', this.addClassList, this);
        this.fetch();
    },

    model: iSpy.Models.ObjcClass,

    addClassList: function(classList) {
        this.reset();
        for(index = 0; index < classList['classes'].length; ++index) {
            this.add({name: classList['classes'][index]});
        }
        console.log(this);
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

