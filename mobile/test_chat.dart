import 'dart:convert';
import 'dart:io';

void main() async {
  final httpClient = HttpClient();
  
  final loginReq = await httpClient.postUrl(Uri.parse('http://127.0.0.1:3000/api/v1/auth/login'));
  loginReq.headers.contentType = ContentType.json;
  loginReq.write(jsonEncode({'email': 'student1@gmail.com', 'password': 'Password@123'}));
  
  final loginRes = await loginReq.close();
  final loginBody = await loginRes.transform(utf8.decoder).join();
  final loginJson = jsonDecode(loginBody);
  
  final token = loginJson['data']['tokens']['access']['token'];
  
  final roomReq = await httpClient.getUrl(Uri.parse('http://127.0.0.1:3000/api/v1/chat/rooms'));
  roomReq.headers.add('Authorization', 'Bearer $token');
  
  final roomRes = await roomReq.close();
  final roomBody = await roomRes.transform(utf8.decoder).join();
  
  print(roomBody);
  exit(0);
}
