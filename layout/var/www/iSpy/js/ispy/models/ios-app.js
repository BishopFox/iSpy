// iOSApp Model
// ----------
iSpy.Models.iOSApp = Backbone.Model.extend({

    defaults: {
        'CFBundleDisplayName': 'iOS App',
        'CFBundleIdentifier': 'com.foobar',
        'CFBundleVersion': '1337',
        'ASLROffset': 0,
        'classes': [],
    },


    initialize: function() {
        console.log("[Models|iOSApp] initialize");
        iSpy.Events.on('sync:appInfo', this.set, this);
        iSpy.Events.on('sync:ASLR', this.set, this);
        iSpy.Events.on('sync:classList', this.set, this);
    },

    rpcRead: [
        {
            "messageType": "ASLR",
            "messageData": {}
        },
        {
            "messageType": "appInfo",
            "messageData": {}
        },
        {
            "messageType": "classList",
            "messageData": {}
        },
    ],

});
