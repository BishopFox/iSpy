
(function ( $ ) {

	$.fn.renderAppClass = function(className) {
		var appClass = new ClassRenderer(className);
		$(this).html(appClass.renderHTML());
		return this;
	};

}( jQuery ));