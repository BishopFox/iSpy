// The iOSApp Index View
// -----------------------
iSpy.Views.iOSAppIndex = Backbone.View.extend({

    el: '#page-wrapper',

    template: mktemplate("iosapp-index"),

    initialize: function() {
        iSpy.Events.on('iosapp:index', this.render, this);
    },

    render: function() {
        var template = this.template();
        this.$el.html(template);
        return this;
    },

});
