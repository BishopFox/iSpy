// The iOSApp Index View
// -----------------------
iSpy.Views.iOSAppView = Backbone.View.extend({

    tagName: 'div',

    template: Handlebars.templates.iOSApp,

    initialize: function() {
        this.model.on('change', this.render, this);
    },

    render: function() {
        var template = this.template(this.model.toJSON());
        this.$el.html(template);
        return this;
    },

});
