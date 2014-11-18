// ObjcClass Model
// -------------------
iSpy.Models.ObjcClass = Backbone.Model.extend({

    defaults: {
        "name": "",
        "classMethods": [],
        "instanceMethods": [],
        "properties": [],
    },

    validate: function(attrs) {
        if ( !attrs.name ) {
            return "ObjcClass 'name' cannot be falsey";
        }
    },

    initialize: function() {
        console.log("[Models|ObjcClass] initialize");
        iSpy.Events.on("sync:" + this.attributes.name, this.set, this);

    },

    fetchAll: function() {
        this.createClassRpcRead("iVarsForClass");
        this.createClassRpcRead("methodsForClass");
        this.createClassRpcRead("propertiesForClass");
        this.fetch();
    },

    createClassRpcRead: function(messageType) {
        this.rpcRead.push({
            "messageType": messageType,
            "messageData": {
                "class": this.attributes.name,
            }
        });
    },

    /* Created when the object is init'd */
    rpcRead: [
    ],

});
