//https://hackernoon.com/how-to-build-an-ios-share-extension-in-swift-4a2019935b2e
var GetURL = function() {};
GetURL.prototype = {
run: function(arguments) {

    var amazonReg = new RegExp('^https?:\/\/(www.)?amazon');
    var results;
    console.log("called:");
    if (amazonReg.test(document.URL)){
        results = document.URL.match( new RegExp('\\d{9}[\\d|X]'))
    }else{
        results = document.body.innerText.match( new RegExp('[978|979]\\d{9}[\\d|X]') );
    }
    console.log("js:",results);
    arguments.completionFunction({"URL": document.URL, "isbn": results ? results[0] : null});
    //arguments.completionFunction({"URL": document.URL });
}
};
var ExtensionPreprocessingJS = new GetURL;

