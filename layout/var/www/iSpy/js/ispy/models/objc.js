// ObjcClass Model
// -------------------
iSpy.Models.ObjcClass = Backbone.Model.extend({

    defaults: {
        "name": "",
        "classMethods": [],
        "instanceMethods": [],
        "properties": [],
    },


    initialize: function() {
        console.log("[Models|ObjcClass] initialize");
    },

    rpcRead: [
    ],

});


// ObjcMethod Model
// -------------------
iSpy.Models.ObjcMethod = Backbone.Model.extend({

    defaults: {
        "name": "",
        "arguments": [],
        "returnType": null,
        "instanceMethod": true,
    },


    initialize: function() {
        console.log("[Models|ObjcMethod] initialize");
    },

    rpcRead: [
    ],

});