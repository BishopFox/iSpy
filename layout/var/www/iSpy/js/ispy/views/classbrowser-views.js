// The Class Index View
// -----------------------
iSpy.Views.ClassBrowserIndex = Backbone.View.extend({

    el: '#page-wrapper',

    template: mktemplate("classbrowser-index"),

    initialize: function() {
        iSpy.Events.on('classbrowser:index', this.render, this);
        iSpy.Events.on('sync:classList', this.set, this);
    },

    render: function() {
        var template = this.template();
        this.$el.html(template);
        return this;
    },

});