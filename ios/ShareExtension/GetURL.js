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
    if (results){
        arguments.completionFunction({"URL": document.URL, "isbn": results[0]});
    }else{
        arguments.completionFunction({"URL": document.URL});
    }    
    //arguments.completionFunction({"URL": document.URL });
}
};
var ExtensionPreprocessingJS = new GetURL;

