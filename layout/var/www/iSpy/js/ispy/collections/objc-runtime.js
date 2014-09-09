

iSpy.Collections.ObjcRuntime = Backbone.Collection.extend({

    initialize: function() {
        iSpy.Events.on('sync:classList', this.set, this);
    },

    model: iSpy.Models.ObjcClass,

});

