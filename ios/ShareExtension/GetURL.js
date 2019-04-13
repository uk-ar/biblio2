//https://hackernoon.com/how-to-build-an-ios-share-extension-in-swift-4a2019935b2e
var GetURL = function() {};
GetURL.prototype = {
run: function(arguments) {
    //var results = document.body.innerText.match( new RegExp('[978|979]\\d{9}[\\d|X]') );
    //arguments.completionFunction({"URL": document.URL, "isbn": results ? results[0] : null});
    arguments.completionFunction({"URL": document.URL });
}
};
var ExtensionPreprocessingJS = new GetURL;

