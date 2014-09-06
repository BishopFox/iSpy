/* Our Global Namespace */
window.iSpy = {
    Models: {},
    Collections: {},
    Views: {},
    Router: {},
};

window.mktemplate = function(id) {
    return _.template( $('#' + id).html() );
};

window.iSpyEvents = _.extend({}, Backbone.Events);
