(function() {
  var template = Handlebars.template, templates = Handlebars.templates = Handlebars.templates || {};
templates['ObjcClassBrowser'] = template({"1":function(depth0,helpers,partials,data) {
  var helper, functionType="function", helperMissing=helpers.helperMissing, escapeExpression=this.escapeExpression;
  return "            <a href=\"#\" class=\"list-group-item animated fadeIn\">\n                <h5 class=\"list-group-item-heading\">\n                    "
    + escapeExpression(((helper = (helper = helpers.name || (depth0 != null ? depth0.name : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"name","hash":{},"data":data}) : helper)))
    + " <i class=\"fa fa-fw fa-angle-right\"></i>\n                </h5>\n            </a>\n";
},"3":function(depth0,helpers,partials,data) {
  return "            <p class=\"text-center\">\n                <i class=\"fa fa-fw fa-refresh fa-spin\"></i>\n                Loading ...\n            </p>\n";
  },"compiler":[6,">= 2.0.0-beta.1"],"main":function(depth0,helpers,partials,data) {
  var stack1, buffer = "<h1 class=\"page-header\">\n    <i class=\"fa fa-fw fa-code\"></i>\n    Class Browser\n</h1>\n<div class=\"row\">\n    <div class=\"list-group col-md-4\">\n";
  stack1 = helpers.each.call(depth0, (depth0 != null ? depth0.objc_classes : depth0), {"name":"each","hash":{},"fn":this.program(1, data),"inverse":this.program(3, data),"data":data});
  if (stack1 != null) { buffer += stack1; }
  return buffer + "    </div>\n    <div id=\"\" class=\"col-md-8\">\n    </div>\n</div>";
},"useData":true});
})();