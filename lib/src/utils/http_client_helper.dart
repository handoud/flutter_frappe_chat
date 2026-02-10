import 'package:http/http.dart' as http;
import 'http_client_io.dart' if (dart.library.html) 'http_client_web.dart';

http.Client getHttpClient() => getClient();
