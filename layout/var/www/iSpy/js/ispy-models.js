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