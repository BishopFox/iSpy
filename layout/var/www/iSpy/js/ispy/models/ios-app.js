// iOSApp Model
// ----------
iSpy.Models.iOSApp = Backbone.Model.extend({

    defaults: {
        CFBundleDisplayName: 'iOS App',
        CFBundleIdentifier: 'com.foobar',
        CFBundleVersion: '1337',
    },


    initialize: function() {
        console.log("[Models|iOSApp] initialize");
        iSpy.Events.on('ispy:appInfo', this.updateAppInfo, this);
    },

    updateAppInfo: function(data) {
        console.log("[Models|iOSApp] updateAppInfo: " + data);
        console.log(data);
        this.set(data);
    },

    rpcRead: {
        "messageType": "appInfo",
        "messageData": {}
    },

});
