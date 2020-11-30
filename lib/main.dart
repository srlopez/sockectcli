import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_ip/get_ip.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: SocketClient());
  }
}

SocketClientState pageState;

class SocketClient extends StatefulWidget {
  @override
  SocketClientState createState() {
    pageState = SocketClientState();
    return pageState;
  }
}

class SocketClientState extends State<SocketClient> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  String localIP = "";
  int port = 7654;
  List<MessageItem> items = List<MessageItem>();

  TextEditingController ipCon = TextEditingController();
  TextEditingController msgCon = TextEditingController();

  Socket socket;
  var alias = 'soymovil';
  var logincontroller = TextEditingController(text: 'soymovil');

  @override
  void initState() {
    super.initState();
    getIP();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadServerIP();
    });
  }

  @override
  void dispose() {
    disconnectFromServer();
    super.dispose();
  }

  void getIP() async {
    var ip = await GetIp.ipAddress;
    setState(() {
      localIP = ip;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: scaffoldKey,
        appBar: AppBar(title: Text("Socket Client $localIP")),
        body: Column(
          children: <Widget>[
            loginArea(),
            connectArea(),
            messageListArea(),
            submitArea(),
          ],
        ));
  }

  Widget loginArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18.0, 5, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alias/Login/Nick:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(
            controller: logincontroller,
          ),
        ],
      ),
    );
  }

  Widget connectArea() {
    return Card(
      child: ListTile(
        dense: true,
        leading: Text("Server IP"),
        title: TextField(
          controller: ipCon,
          decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              isDense: true,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(5)),
                borderSide: BorderSide(color: Colors.grey[300]),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(5)),
                borderSide: BorderSide(color: Colors.grey[400]),
              ),
              filled: true,
              fillColor: Colors.grey[50]),
        ),
        trailing: RaisedButton(
          child: Text((socket != null) ? "Disconnect" : "Connect"),
          onPressed: (socket != null) ? disconnectFromServer : connectToServer,
        ),
      ),
    );
  }

  Widget messageListArea() {
    return Expanded(
      child: ListView.builder(
          reverse: true,
          itemCount: items.length,
          itemBuilder: (context, index) {
            MessageItem item = items[index];
            return Container(
              alignment: (item.owner == 'yo')
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: (item.owner == 'yo')
                        ? Colors.blue[100]
                        : Colors.grey[200]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      (item.owner == 'yo') ? alias : item.owner,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      item.content,
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            );
          }),
    );
  }

  Widget submitArea() {
    return Card(
      child: ListTile(
        title: TextField(
          controller: msgCon,
        ),
        trailing: IconButton(
          icon: Icon(Icons.send),
          color: Colors.blue,
          disabledColor: Colors.grey,
          onPressed: (socket != null) ? submitMessage : null,
        ),
      ),
    );
  }

  void connectToServer() async {
    print('conectando ...');
    _storeServerIP();
    alias = logincontroller.text;

    Socket.connect(ipCon.text, port, timeout: Duration(seconds: 5))
        .then((misocket) {
      setState(() {
        socket = misocket;
      });
      print(
          "connected to ${socket.remoteAddress.address}:${socket.remotePort}");
      // Nos presentamos al servidor
      sendMsg('LOGIN', alias);
      showSnackBarWithKey(
          "connected to ${socket.remoteAddress.address}:${socket.remotePort}");
      socket.listen(
        (data) => onData(utf8.decode(data)),
        //(data) => onData(String.fromCharCodes(data).trim()),
        //(data) => onData(String(decoding: data,as: UTF8.self).trim()),
        onDone: onDone,
        onError: onError,
      );
    }).catchError((e) {
      showSnackBarWithKey(e.toString());
    });
  }

  void onData(json) {
    var data = jsonDecode(json);
    print('onData: $data');
    setState(() {
      Map msg = jsonDecode(json);

      switch (msg["action"]) {
        case 'CLIENT_COUNTER':
          setState(() {
            items.insert(
                0,
                MessageItem(
                  'INFO',
                  'conectados ${data["value"]} clientes\n${data["clients"]}',
                ));
          });

          break;
        case 'MSG':
          setState(() {
            items.insert(0, MessageItem(data['from'], data['value']));
          });

          break;
        default:
          {
            print('No reconocido: $data');
          }
          break;
      }
    });
  }

  void onDone() {
    showSnackBarWithKey("Connection has terminated.");
    disconnectFromServer();
  }

  void onError(e) {
    print("onError: $e");
    showSnackBarWithKey(e.toString());
    disconnectFromServer();
  }

  void disconnectFromServer() {
    sendMsg('QUIT', '');
    print("disconnectFromServer");

    socket.close();
    setState(() {
      socket = null;
    });
  }

  void sendMsg(String action, dynamic value, [Map data = const {}]) {
    var msg = Map();
    msg["action"] = action;
    msg["value"] = value.toString();
    msg.addAll(data);

    socket?.write('${jsonEncode(msg)}');
  }

  void _storeServerIP() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.setString("serverIP", ipCon.text);
  }

  void _loadServerIP() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    setState(() {
      ipCon.text = sp.getString("serverIP");
    });
  }

  void submitMessage() {
    if (msgCon.text.isEmpty) return;
    var msg = msgCon.text;
    msgCon.clear();

    setState(() {
      items.insert(0, MessageItem('yo', msg));
    });

    if (msg.indexOf('@') > -1)
      sendMsg('MSG', msg.split('@')[0], {'to': msg.split('@')[1]});
    else
      sendMsg('MSG', msg, {'to': 'ALL'});
  }

  void showSnackBarWithKey(String message) {
    scaffoldKey.currentState
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Done',
          onPressed: () {},
        ),
      ));
  }
}

class MessageItem {
  String owner;
  String content;

  MessageItem(this.owner, this.content);
}
