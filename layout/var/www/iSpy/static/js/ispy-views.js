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