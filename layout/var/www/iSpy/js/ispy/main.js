/************
 *   iSpy   *
 ************/
(function() {

    /* iSpy Namespace */
    window.iSpy = {
        Models: {},
        Collections: {},
        Views: {},
        Router: {},
    };

    /*
     * This is a template helper function to automatically pull the template
     * markup from the main DOM using jquery.
     */
    window.template = function(id) {
        return _.template( $('#' + id).html() );
    };

    window.iSpyEvent = _.extend({}, Backbone.Events);

})();
