import 'dart:convert';
import 'package:example/config.dart';
import 'package:flutter/material.dart';
import 'package:rocket_chat_connector_flutter/models/authentication.dart';
import 'package:rocket_chat_connector_flutter/models/channel.dart';
import 'package:rocket_chat_connector_flutter/models/room.dart';
import 'package:rocket_chat_connector_flutter/models/user.dart';
import 'package:rocket_chat_connector_flutter/services/authentication_service.dart';
import 'package:rocket_chat_connector_flutter/services/http_service.dart' as rocket_http_service;
import 'package:rocket_chat_connector_flutter/web_socket/notification.dart' as rocket_notification;
import 'package:rocket_chat_connector_flutter/web_socket/web_socket_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

void main() => runApp(MyApp());

final Channel channel = Channel(id: Config.channelId);
final Room room = Room(id: Config.roomId);
final rocket_http_service.HttpService rocketHttpService = rocket_http_service.HttpService(Uri.parse(Config.serverUrl));

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final title = 'Rocket Chat WebSocket Demo';

    return MaterialApp(
      title: title,
      home: MyHomePage(
        title: title,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  MyHomePage({Key key, @required this.title}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  TextEditingController _controller = TextEditingController();
  WebSocketChannel webSocketChannel;
  WebSocketService webSocketService = WebSocketService();
  User user;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Authentication>(
        future: getAuthentication(),
        builder: (context, AsyncSnapshot<Authentication> snapshot) {
          if (snapshot.hasData) {
            Config.xAuthToken = snapshot.data?.data?.authToken;
            Config.xUserId = snapshot.data?.data?.userId;
            user = snapshot.data.data.me;
            webSocketChannel = webSocketService.connectToWebSocket(Config.webSocketUrl, snapshot.data);
            webSocketService.streamNotifyUserSubscribe(webSocketChannel, user);
            return _getScaffold();
          } else {
            return Center(child: CircularProgressIndicator());
          }
        });
  }

  Scaffold _getScaffold() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Form(
              child: TextFormField(
                controller: _controller,
                decoration: InputDecoration(labelText: 'Send a message'),
              ),
            ),
            StreamBuilder(
              stream: webSocketChannel.stream,
              builder: (context, snapshot) {
                print(snapshot.data);
                rocket_notification.Notification notification =
                    snapshot.hasData ? rocket_notification.Notification.fromMap(jsonDecode(snapshot.data)) : null;
                print(notification);
                webSocketService.streamNotifyUserSubscribe(webSocketChannel, user);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Text(notification != null ? '${notification.toString()}' : ''),
                );
              },
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendMessage,
        tooltip: 'Send message',
        child: Icon(Icons.send),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void _sendMessage() async {
    if (_controller.text.isNotEmpty) {
      webSocketService.sendMessageOnChannel(_controller.text, webSocketChannel, channel);
      // webSocketService.sendMessageOnRoom(_controller.text, webSocketChannel, room);
      await http
          .post(
        Uri.parse('http://127.0.0.1:3000/api/v1/chat.sendMessage'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'X-Auth-Token': Config.xAuthToken,
          'X-User-Id': Config.xUserId,
        },
        body: jsonEncode(<String, dynamic>{
          'message': {
            'rid': Config.roomId,
            'msg': _controller.text,
          },
        }),
      )
          .then((value) {
        print(value.statusCode);
        print(value.reasonPhrase);
        print(value.body);
      });
    }
  }

  @override
  void dispose() {
    webSocketChannel.sink.close();
    super.dispose();
  }

  Future<Authentication> getAuthentication() async {
    final AuthenticationService authenticationService = AuthenticationService(rocketHttpService);
    return await authenticationService.login(Config.username, Config.password);
  }
}
