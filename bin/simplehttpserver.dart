import 'dart:io';
import 'dart:async';

// CONSTANTS
final EXIT_INVALID_STARTUP_LOCATION = 1;
final HOST = "127.0.0.1";
final PORT = 8000;
final THIS_FOLDER = "bin";
final README_FILE = "README.md";
const DEFAULT_FILES = const ["app.html","index.html"];
final Map<String,String> MIMETYPES = {
   "css": "text/css",
   "html": "text/html",
   "dart": "application/dart",
   "js": "application/javascript",
   "maps": "text/plain",
   "deps": "text/plain",
   "swf" : "application/x-shockwave-flash",
   "jpeg": "image/jpeg",
   "jpg" : "image/jpeg",
   "png" : "image/png",
   "xml" : "application.xml",
   "md"  : "text/plain",
   "markdown" : "text/plain",
   "txt" : "text/plain",
   "json": "application/json"
};


main() {
  print("Simple Http Server for Dart-Phonecat tutorial");
  
  var serverRoot = initializeServerRoot();
  validateServerRoot(serverRoot); // may exit with error
  
  var httpServer = initializeHttpServer(serverRoot);  
  httpServer.listen(HOST, PORT);
  print("Listening for requests on http://$HOST:$PORT/");
}

/** Validate that the simpleServer was started in the correct working
 * directory, so that it can find the correct files.
 * 
 * The correct path to start this script is 
 * `dart bin/simplehttpserver.dart` but it is also likely that users will
 * start up actually within the bin folder, eg: `dart simplehttpserver.dart`
 * so fix that without failing.
 * 
 *  :If startup in `bin` folder (represented by [THIS_FOLDER], 
 *   trim the path and look for a README.md file
 *  :If not startup in `b` folder, then look for a README.md file
 *  :If no README.md file found, then exit with error 1 
 */
String initializeServerRoot() {
  Directory dir = new Directory(new File(".").fullPathSync());
  
  var currentPath = dir.path;
  
  if (currentPath.toLowerCase().endsWith(THIS_FOLDER)) {
    // remove "bin" if it appears at the end.
    var thisFolderIndex = currentPath.toLowerCase().lastIndexOf(THIS_FOLDER);
    currentPath = dir.path.substring(0, thisFolderIndex);    
  }
  
  // add a trailing path separator (if reqd) before setting the serverRoot
  var serverRootPath = new Path(currentPath).toNativePath();
  if (!serverRootPath.endsWith(Platform.pathSeparator)) {
    serverRootPath = "$serverRootPath${Platform.pathSeparator}";
  }
  
  return serverRootPath; // set the serverRoot
}

/**
 * Check that the this server is serving from a valid location (can it see
 * the files that it expects to be serving?)
 * 
 * Exit with error if not.
 */
bool validateServerRoot(String serverRoot) {
  if (!fileExistsSync(serverRoot, README_FILE)) {
    print("""
Error:
This server appears to have been started from this location: 
  $serverRoot
This script should be started from within dart-phonecat/
For example:
  > dart bin/simplehttpserver.dart""");
    exit(EXIT_INVALID_STARTUP_LOCATION); // force exit of this process
  }
  else {
    print("Serving files from: $serverRoot");
  }
}

/**
 * [relFile] is a filename relative to the [serverRoot], without a leading
 * path separator.  Valid values could be `README.md` or 
 * `bin/simplehttpserver.dart'. Any \ or / characters are replaced with the
 * valid path separator.
 */
bool fileExistsSync(String serverRoot, String relFile) {
  relFile = relFile
    .replaceAll(r"\", Platform.pathSeparator)
    .replaceAll(r"/", Platform.pathSeparator);
  return new File("$serverRoot$relFile").existsSync();
}

/**
 * Starts handling static file requests from the server root.
 */
HttpServer initializeHttpServer(String serverRoot) {
  var httpServer = new HttpServer();
  
  // attach handlers
  var staticFiles = new StaticFileServer(serverRoot);
  httpServer.addRequestHandler(staticFiles.matcher, staticFiles.handler);
  httpServer.addRequestHandler((req) => req.method == "OPTIONS", handleOptions);
  httpServer.defaultRequestHandler = defaultHandler;
  httpServer.onError = (error) => print("Sever error: $error");  
  
  return httpServer;
}

class StaticFileServer {
  final serverRoot;
  
  // constructor
  StaticFileServer(this.serverRoot);

  /**
   * GET requests for files that exist will return true.
   * Requests ending with a trailing / will default to a request for index.html
   */
  bool matcher(req) {
    if (req.method != "GET") return false;
  
    // GET request, so return true if the file exists.
    // Try for each default file.  If the a real path is specified, 
    // then this will return true in the first iteration, otherwise, it will
    // try for each default.
    for (var defaultFile in DEFAULT_FILES) {
      if (fileExistsSync(serverRoot, 
          _getRelativeFilePathFromReq(req,defaultFile))) {
        return true;
      }
      // else, continue
    }
    
    return false;          
  }
  
  /**
   * Load the requested file and serve it to the response.
   */
  void handler(req, res) {
    addCorsHeaders(res);
    
    var requestedFile = "";
    for (var defaultFile in DEFAULT_FILES) {
      requestedFile = _getRelativeFilePathFromReq(req,defaultFile);
      if (fileExistsSync(serverRoot, requestedFile)) {
        break;
      }
      // else, continue
      // on the basis that the matcher got us here, so we will get a file
      // on the next iteration.
    }
    
    print("${req.method}: ${requestedFile}");
    
    addContentType(res,requestedFile);
    
    var file = new File("$serverRoot$requestedFile");
    file.openInputStream().pipe(res.outputStream);
  }
  
  /**
   * Converts a [req.path] into a relative file path for the application to
   * server.  [defaultFile] defines the file to search for if the [req.path] ends
   * with a trailing /
   */
  String _getRelativeFilePathFromReq(req, [String defaultFile]) {
    var requestedPath = req.path.replaceAll(r"/", Platform.pathSeparator);
    
    // trim any leading path separator to make for requested file relative
    if (requestedPath.startsWith(Platform.pathSeparator) && 
        requestedPath.length > 1) {
      requestedPath = requestedPath.substring(1);
    }
    
    // if ends with trailing path separator, add the default file
    if (defaultFile != null && requestedPath.endsWith(Platform.pathSeparator)) {
      requestedPath = "$requestedPath$defaultFile";  
    }
    return requestedPath;
  }
}

/**
 * Handle OPTIONS requests (where we can add CORS headers).
 */
void handleOptions(req,HttpResponse res) {
  addCorsHeaders(res);
  print("${req.method}: ${req.path}");
  res.statusCode = HttpStatus.NO_CONTENT;  
  res.outputStream.close();
}

/**
 * Default handler returns 404 not found
 */
void defaultHandler(req,HttpResponse res) {
  addCorsHeaders(res);
  res.statusCode = HttpStatus.NOT_FOUND;  
  res.outputStream.writeString("Not found: ${req.method}, ${req.path}");
  res.outputStream.close();
}


/**
 * Add Cross-site headers to enable accessing this server from pages
 * not served by this server
 * 
 * See: http://www.html5rocks.com/en/tutorials/cors/ 
 * and http://enable-cors.org/server.html
 */
void addCorsHeaders(HttpResponse res) {
  res.headers.add("Access-Control-Allow-Origin", "*, ");
  res.headers.add("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  res.headers.add("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
}

/**
 * Guesses the mimetype from the filename extension.
 */
void addContentType(res, filename) {
  var path = new Path(filename);
  var ext = path.extension;
  if (MIMETYPES[ext] != null) {
    res.headers.add(HttpHeaders.CONTENT_TYPE, MIMETYPES[ext]);
  }
}