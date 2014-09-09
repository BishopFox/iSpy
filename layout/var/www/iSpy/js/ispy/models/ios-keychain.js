// iOSKeychain Model
// -------------------
iSpy.Models.iOSKeychain = Backbone.Model.extend({

    defaults: {
        "Identities": [],
        "Generic Passwords": [],
        "Certificates": [],
        "Internet Passwords": [],
        "Keys": [],
    },


    initialize: function() {
        console.log("[Models|iOSKeychain] initialize");
        iSpy.Events.on('sync:keyChainItems', this.set, this);
    },

    rpcRead: [
        {
            "messageType": "keyChainItems",
            "messageData": {}
        },
    ],

});
