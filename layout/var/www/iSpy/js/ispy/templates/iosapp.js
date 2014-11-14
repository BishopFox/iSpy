(function() {
  var template = Handlebars.template, templates = Handlebars.templates = Handlebars.templates || {};
templates['iosapp'] = template({"1":function(depth0,helpers,partials,data) {
  var helper, functionType="function", helperMissing=helpers.helperMissing, escapeExpression=this.escapeExpression;
  return "        <img src=\""
    + escapeExpression(((helper = (helper = helpers.imageURI || (depth0 != null ? depth0.imageURI : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"imageURI","hash":{},"data":data}) : helper)))
    + "\"></img>\n";
},"compiler":[6,">= 2.0.0-beta.1"],"main":function(depth0,helpers,partials,data) {
  var stack1, helper, functionType="function", helperMissing=helpers.helperMissing, escapeExpression=this.escapeExpression, lambda=this.lambda, buffer = "<h1 class=\"page-header\">\n";
  stack1 = helpers['if'].call(depth0, (depth0 != null ? depth0.imageURI : depth0), {"name":"if","hash":{},"fn":this.program(1, data),"inverse":this.noop,"data":data});
  if (stack1 != null) { buffer += stack1; }
  return buffer + "    "
    + escapeExpression(((helper = (helper = helpers.CFBundleDisplayName || (depth0 != null ? depth0.CFBundleDisplayName : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"CFBundleDisplayName","hash":{},"data":data}) : helper)))
    + "\n</h1>\n<div class=\"row\">\n    <div class=\"list-group col-md-6\">\n        <dl class=\"dl-horizontal list-group-item dl-heading\">\n            <span>\n                <h4>\n                    <i class=\"fa fa-fw fa-info-circle\"></i>\n                    Application Information\n                </h4>\n            </span>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <dt>CFBundleDisplayName</dt>\n            <dd>"
    + escapeExpression(((helper = (helper = helpers.CFBundleDisplayName || (depth0 != null ? depth0.CFBundleDisplayName : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"CFBundleDisplayName","hash":{},"data":data}) : helper)))
    + "</dd>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <dt>CFBundleIdentifier</dt>\n            <dd>"
    + escapeExpression(((helper = (helper = helpers.CFBundleIdentifier || (depth0 != null ? depth0.CFBundleIdentifier : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"CFBundleIdentifier","hash":{},"data":data}) : helper)))
    + "</dd>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <dt>Version</dt>\n            <dd>"
    + escapeExpression(((helper = (helper = helpers.CFBundleVersion || (depth0 != null ? depth0.CFBundleVersion : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"CFBundleVersion","hash":{},"data":data}) : helper)))
    + "</dd>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <dt>BuildMachineOSBuild</dt>\n            <dd>"
    + escapeExpression(((helper = (helper = helpers.BuildMachineOSBuild || (depth0 != null ? depth0.BuildMachineOSBuild : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"BuildMachineOSBuild","hash":{},"data":data}) : helper)))
    + "</dd>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <dt>NSMainNibFile</dt>\n            <dd>"
    + escapeExpression(((helper = (helper = helpers.NSMainNibFile || (depth0 != null ? depth0.NSMainNibFile : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"NSMainNibFile","hash":{},"data":data}) : helper)))
    + "</dd>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <dt>DTPlatformBuild</dt>\n            <dd>"
    + escapeExpression(((helper = (helper = helpers.DTPlatformBuild || (depth0 != null ? depth0.DTPlatformBuild : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"DTPlatformBuild","hash":{},"data":data}) : helper)))
    + "</dd>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <dt>DTCompiler</dt>\n            <dd>"
    + escapeExpression(((helper = (helper = helpers.DTCompiler || (depth0 != null ? depth0.DTCompiler : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"DTCompiler","hash":{},"data":data}) : helper)))
    + "</dd>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <dt>CFBundleDisplayName</dt>\n            <dd>"
    + escapeExpression(((helper = (helper = helpers.CFBundleDisplayName || (depth0 != null ? depth0.CFBundleDisplayName : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"CFBundleDisplayName","hash":{},"data":data}) : helper)))
    + "</dd>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <dt>FBundleShortVersionString</dt>\n            <dd>"
    + escapeExpression(((helper = (helper = helpers.CFBundleShortVersionString || (depth0 != null ? depth0.CFBundleShortVersionString : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"CFBundleShortVersionString","hash":{},"data":data}) : helper)))
    + "</dd>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <dt>DTSDKName</dt>\n            <dd>"
    + escapeExpression(((helper = (helper = helpers.DTSDKName || (depth0 != null ? depth0.DTSDKName : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"DTSDKName","hash":{},"data":data}) : helper)))
    + "</dd>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <dt>CFBundleExecutable</dt>\n            <dd>"
    + escapeExpression(((helper = (helper = helpers.CFBundleExecutable || (depth0 != null ? depth0.CFBundleExecutable : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"CFBundleExecutable","hash":{},"data":data}) : helper)))
    + "</dd>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <dt>DTXcode</dt>\n            <dd>"
    + escapeExpression(((helper = (helper = helpers.DTXcode || (depth0 != null ? depth0.DTXcode : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"DTXcode","hash":{},"data":data}) : helper)))
    + "</dd>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <dt>CFBundleInfoDictionaryVersion</dt>\n            <dd>"
    + escapeExpression(((helper = (helper = helpers.CFBundleInfoDictionaryVersion || (depth0 != null ? depth0.CFBundleInfoDictionaryVersion : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"CFBundleInfoDictionaryVersion","hash":{},"data":data}) : helper)))
    + "</dd>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <dt>DTXcodeBuild</dt>\n            <dd>"
    + escapeExpression(((helper = (helper = helpers.DTXcodeBuild || (depth0 != null ? depth0.DTXcodeBuild : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"DTXcodeBuild","hash":{},"data":data}) : helper)))
    + "</dd>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <dt>DTSDKBuild</dt>\n            <dd>"
    + escapeExpression(((helper = (helper = helpers.DTSDKBuild || (depth0 != null ? depth0.DTSDKBuild : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"DTSDKBuild","hash":{},"data":data}) : helper)))
    + "</dd>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <dt>MinimumOSVersion</dt>\n            <dd>"
    + escapeExpression(((helper = (helper = helpers.MinimumOSVersion || (depth0 != null ? depth0.MinimumOSVersion : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"MinimumOSVersion","hash":{},"data":data}) : helper)))
    + "</dd>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <dt>DTPlatformVersion</dt>\n            <dd>"
    + escapeExpression(((helper = (helper = helpers.DTPlatformVersion || (depth0 != null ? depth0.DTPlatformVersion : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"DTPlatformVersion","hash":{},"data":data}) : helper)))
    + "</dd>\n        </dl>\n    </div>\n    <div class=\"list-group col-md-6\">\n        <dl class=\"dl-horizontal list-group-item dl-heading\">\n            <span>\n                <h4>\n                    <i class=\"fa fa-fw fa-line-chart\"></i>\n                    Statistics\n                </h4>\n            </span>\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <span class=\"badge\">"
    + escapeExpression(lambda(((stack1 = (depth0 != null ? depth0.classes : depth0)) != null ? stack1.length : stack1), depth0))
    + "</span>\n            Number of classes\n        </dl>\n        <dl class=\"dl-horizontal list-group-item\">\n            <span class=\"badge\" id=\"ASLRBadge\">\n                "
    + escapeExpression(((helpers.toHex || (depth0 && depth0.toHex) || helperMissing).call(depth0, (depth0 != null ? depth0.ASLROffset : depth0), {"name":"toHex","hash":{},"data":data})))
    + "\n            </span>\n            ASLR slide\n        </dl>\n    </div>\n</div><!-- /.row -->\n";
},"useData":true});
})();