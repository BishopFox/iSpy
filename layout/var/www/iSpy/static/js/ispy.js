/*
 *   Objective-C Models
 */
var ObjcClass = Backbone.Model.extend({

    defaults: {
        'name': null,
    },

    validate: function(attrs) {
        if (!attrs.name) {
            return 'ObjcClass must have a name';
        }
    },

});

var ObjcMethod = Backbone.Model.extend({

    defaults: {
        'name': null,
    },

    validate: function(attrs) {
        if (!attrs.name) {
            return 'ObjcMethod must have a name';
        }
    },

});

var ObjcMsgSend = Backbone.Model.extend({

    defaults: {
        'class': null,
        'method': null,
        'parameters': [],
    },

    validate: function(attrs) {
        if (!attrs.class) {
            return 'ObjcMsgSend must have a class';
        }
        if (!attrs.method) {
            return 'ObjcMsgSend must have a method';
        }
    },

});

/*
 * Objective-C Views
 */
var ObjcMsgSendView = Backbone.View.extend({

    template: _.template( $("#objc-msg-send-template").html() ),

    initialize: function() {
        this.render();
    },

    render: function() {
        this.template(this.model.toJSON());
    },

});


$(document).ready(function() {
    console.log("Ready!");
    var objc_cls = new ObjcClass({name: "NSString"});
    console.log(objc_cls);
    var objc_method = new ObjcMethod({name: "UTF8String"});
    var msg_send = new ObjcMsgSend({class: objc_cls, method: objc_method});
    var v = new ObjcMsgSendView({model: msg_send});

    console.log(v.$el);
});
