


iSpy.Views.ObjcClassList = Backbone.View.extend({

    el: '#objc-class-list',

    initialize: function() {
        this.collection.on('classListChange', this.render, this);
    },

    render: function() {

        this.collection.each(function(objcClass, index) {
            var objcClassView = new iSpy.Views.ObjcClassListItem({model: objcClass});
            if (index === 0) {
                this.$el.html(objcClassView.render().el);
            } else {
                this.$el.append(objcClassView.render().el);
            }
        }, this);

        return this;
    },

});

iSpy.Views.ObjcClassListItem = Backbone.View.extend({

    tagName: 'a',

    template: Handlebars.templates.ObjcClassListItem,

    model: iSpy.Models.ObjcClass,

    render: function() {
        this.$el.addClass("list-group-item");
        this.$el.attr('href', "#classbrowser/" + this.model.cid);
        var template = this.template(this.model.toJSON());
        this.$el.html(template);
        return this;
    },

});

