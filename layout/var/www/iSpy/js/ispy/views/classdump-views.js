// The Class Index View
// -----------------------
iSpy.Views.ClassDumpIndex = Backbone.View.extend({

    el: '#page-wrapper',

    template: mktemplate("classdump-index"),

    initialize: function() {
        iSpy.Events.on('classdump:index', this.render, this);
    },

    render: function() {
        var template = this.template();
        this.$el.html(template);
        return this;
    },

});