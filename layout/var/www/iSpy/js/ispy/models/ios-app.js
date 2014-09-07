// iOSApp Model
// ----------
iSpy.Models.iOSApp = Backbone.Model.extend({

    defaults: {
        CFBundleDisplayName: 'iOS App',
        CFBundleIdentifier: 'com.foobar',
        CFBundleVersion: '1337',
        ASLROffset: 0,
    },


    initialize: function() {
        console.log("[Models|iOSApp] initialize");
        iSpy.Events.on('ispy:appInfo', this.set, this);
        iSpy.Events.on('ispy:ASLR', this.set, this);
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
    ],

});
