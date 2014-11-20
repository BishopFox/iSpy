// ObjcClass Model
// -------------------
iSpy.Models.ObjcClass = Backbone.Model.extend({

    defaults: {
        "name": null,
    },

    validate: function(attrs) {
        if ( !attrs.name ) {
            return "ObjcClass 'name' cannot be falsey";
        }
    },

    initialize: function() {
        console.log("[Models|ObjcClass] initialize");
        var class_methods = new iSpy.Collections.ObjcMethods();
        this.set("classMethods", class_methods);

        var instance_methods = new iSpy.Collections.ObjcMethods();
        this.set("instanceMethods", instance_methods);

        /* Listen for sync data */
        iSpy.Events.on(this.attributes.name + ":iVars", this.setiVars, this);
        iSpy.Events.on(this.attributes.name + ":methods", this.setMethods, this);
        iSpy.Events.on(this.attributes.name + ":properties", this.setProperties, this);

        /* Create sync messages */
        this.createClassRpcRead("iVarsForClass");
        this.createClassRpcRead("methodsForClass");
        this.createClassRpcRead("propertiesForClass");

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

    setMethods: function(methodList) {
        for(var index = 0; index < methodList.length; ++index) {
            var method = iSpy.Models.ObjcMethod({name: methodList[index]});
        }
    },

});


iSpy.Models.ObjcMethod = Backbone.Model.extend({

    defaults: {
        "name": null,
        "arguments": [],
        "returns": null,
    },

    validate: function(attrs) {
        if ( !attrs.name ) {
            return "ObjcMethod 'name' cannot be falsey";
        }
    },


});
