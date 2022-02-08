import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:flutter_fadein/flutter_fadein.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoRouter.setUrlPathStrategy(UrlPathStrategy.path);
  runApp(ProviderScope(child: MaterialApp.router(
    routeInformationParser: _router.routeInformationParser,
    routerDelegate: _router.routerDelegate,
    theme: ThemeData(
        primaryColor: const Color.fromRGBO(249, 128, 18, 1),
        primarySwatch: MaterialColor(0xfff98012, color),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Inter'
    ),
  )));
}

//TODO Animate token list
//TODO Add QR Code generation
//TODO Use stylized appbar
//TODO Change icon

Map<int, Color> color = {
  50:const Color.fromRGBO(249, 128, 18, .1),
  100:const Color.fromRGBO(249, 128, 18, .2),
  200:const Color.fromRGBO(249, 128, 18, .3),
  300:const Color.fromRGBO(249, 128, 18, .4),
  400:const Color.fromRGBO(249, 128, 18, .5),
  500:const Color.fromRGBO(249, 128, 18, .6),
  600:const Color.fromRGBO(249, 128, 18, .7),
  700:const Color.fromRGBO(249, 128, 18, .8),
  800:const Color.fromRGBO(249, 128, 18, .9),
  900:const Color.fromRGBO(249, 128, 18, 1),
};

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => LoadingPage(),
    ),
    GoRoute(
      path: '/start',
      builder: (context, state) => const StartPage(),
    ),
    GoRoute(
      path: '/introduction',
      builder: (context, state) => const IntroductionPage(),
    ),
    GoRoute(
      path: '/joinclass',
      builder: (context, state) {
        final classid = state.queryParams['classid'];
        return ClassSearchPage(text: classid ?? '', initialerror: state.extra == null ? '' : state.extra as String);
      },
    ),
    GoRoute(
      path: '/class',
      builder: (context, state) => ClassPage(),
    ),
  ],  //TODO Design custom error route
);

class Token {
  final String name;
  final int time;
  final String token;
  final String userid;
  final String sessionkey;
  final String id;

  Token({required this.name, required this.time, required this.token, required this.userid, required this.sessionkey, required this.id});

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      name: json['name'],
      time: json['time'],
      token: json['token'],
      userid: json['userid'],
      sessionkey: json['sessionkey'],
      id: json['id']
    );
  }
}

class Class {
  final String name;
  final String url;
  final String id;
  final List<Token> tokens;

  Class({required this.name, required this.url, required this.id, required this.tokens});

  factory Class.fromJson(Map<String, dynamic> json) {
    return Class(
      name: json['name'],
      url: json['url'],
      id: json['id'],
      tokens: json['tokens'].map((data)=>Token.fromJson(data)).toList().cast<Token>()
    );
  }
}

enum Errorcode {
  none, adminkey, url, website, schoolclass, credentials, tokenExist, internal
}

class Apiresponse {
  final Errorcode errorcode;
  final String errormessage;
  final Class? schoolClass;
  final Token? token;

  Apiresponse({required this.errorcode, required this.errormessage, this.schoolClass, this.token});

  factory Apiresponse.fromJson(Map<String, dynamic> json, {bool loadClass = true}) {
    Errorcode errorcode;
    switch (json['error-code'] as int) {
      case 4000:
        errorcode = Errorcode.none;
        break;
      case 4001:
        errorcode = Errorcode.adminkey;
        break;
      case 4002:
        errorcode = Errorcode.url;
        break;
      case 4003:
        errorcode = Errorcode.website;
        break;
      case 4004:
        errorcode = Errorcode.schoolclass;
        break;
      case 4005:
        errorcode = Errorcode.credentials;
        break;
      case 4006:
        errorcode = Errorcode.tokenExist;
        break;
      case 4007:
        errorcode = Errorcode.internal;
        break;
      default:
        throw UnimplementedError();
    }
    return Apiresponse( //Class
        errorcode: errorcode,
        errormessage: json['error-message'],
        schoolClass: loadClass ? Class.fromJson(json['data']) : null
    );
  }
}

class LoadingPage extends ConsumerWidget {
  LoadingPage({Key? key}) : super(key: key);

  void initState(BuildContext context, WidgetRef ref) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var classid = prefs.getString('classid');
    var classname = prefs.getString('classname');
    if (classname == null || classid == null) {
      context.go('/start');
      return;
    }
    ref.read(currentClassProvider.state).state = Class(name: classname, url: '', id: classid, tokens: []);
    context.go('/class');
  }

  bool firstload = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    firstload ? initState(context, ref) : null;
    firstload = false;
    return const Scaffold();
  }
}


final currentClassProvider = StateProvider((ref) => Class(name: '', url: '', id: '', tokens: []));
final currentPageProvider = StateProvider((ref) => 0);

class ClassPage extends ConsumerWidget { //TODO Preload image
  ClassPage({Key? key}) : super(key: key);

  bool firstload = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    firstload ? precacheImage(Image.asset('assets/rsz_5283.jpg', width: 350).image, context) : null;
    firstload = false;
    final currentPage = ref.watch(currentPageProvider);
    final pages = [const ClassPageBody(), const ClassPageAdd(), ClassPageAddSession()];
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => ScaleTransition(child: child, scale: anim),
          child: currentPage >= 1 ? const Icon(Icons.close, key: ValueKey('1')) : const Icon(Icons.add, key: ValueKey('2')),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        focusElevation: 0,
        highlightElevation: 0,
        onPressed: () {
          ref.read(currentPageProvider.state).state >= 1 ? ref.read(currentPageProvider.state).state = 0 : ref.read(currentPageProvider.state).state = 1;
        },
      ),
      body: AnimatedSwitcher(
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        duration: const Duration(milliseconds: 100),
        transitionBuilder: (child, anim) => FadeTransition(child: child, opacity: anim),
        child: pages[currentPage]
      )
    );
  }
}

class ClassPageAddSession extends HookConsumerWidget {
  ClassPageAddSession({Key? key}) : super(key: key);

  final loadingProvider = StateProvider((ref) => false);
  String error = '';
  bool firstloaded = true;

  void tokentoClass(WidgetRef ref, BuildContext context, String username, String token) async {
    ref.read(loadingProvider.state).state = true;
    if (token.isEmpty || username.isEmpty) {
      error = 'Username and token cannot be empty';
      ref.read(loadingProvider.state).state = false;
      return;
    }
    http.Response response;
    ref.read(loadingProvider.state).state = true;
    try {
      response = await http.post(Uri.parse('http://45.81.232.194:3000/'+ref.read(currentClassProvider.state).state.id+'/add'), headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8'}, body:jsonEncode(<String, String>{"name":username,"token":token}));
    }
    catch (e) {
      error = 'Connection Error';
      ref.read(loadingProvider.state).state = false;
      return;
    }
    switch (Apiresponse.fromJson(jsonDecode(response.body),loadClass: false).errorcode) {
      case Errorcode.schoolclass:
        context.go('/joinclass', extra: 'Can\'t find class');
        return;
      case Errorcode.credentials:
        error = 'Invalid token';
        ref.read(loadingProvider.state).state = false;
        return;
      case Errorcode.tokenExist:
        error = 'Token already exists';
        ref.read(loadingProvider.state).state = false;
        return;
      default:
        break;
    }
    try {
      response = await http.get(Uri.parse('http://45.81.232.194:3000/'+ref.read(currentClassProvider.state).state.id));
    }
    catch (e) {
      error = 'Connection Error';
      ref.read(loadingProvider.state).state = false;
      return;
    }
    switch (response.statusCode) {
      case 200:
        ref.read(currentClassProvider.state).state = Apiresponse.fromJson(jsonDecode(response.body)).schoolClass!;
        ref.read(currentPageProvider.state).state = 0;
        break;
      case 400:
        context.go('/joinclass', extra: 'Class was deleted');
        return;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(loadingProvider);
    final username = useTextEditingController();
    final token = useTextEditingController();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TextField(
            textInputAction: TextInputAction.next,
            enabled: !loading,
            style: TextStyle(
                color: !loading ? Colors.black : const Color.fromRGBO(0, 0, 0, 0.5)
            ),
            controller: username,
            decoration: InputDecoration(
              filled: true,
              hintText: 'Enter username',
              prefixIcon: const Icon(Icons.account_circle),
              suffixIcon: loading ? Container(
                height: 15,
                width: 15,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 15),
                child: const SizedBox(
                  height: 15,
                  width: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.25,
                  ),
                ),
              ) : null,
              enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      style: BorderStyle.none
                  ),
                  borderRadius: BorderRadius.circular(15)
              ),
              focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      style: BorderStyle.none
                  ),
                  borderRadius: BorderRadius.circular(15)
              ),
              disabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      style: BorderStyle.none
                  ),
                  borderRadius: BorderRadius.circular(15)
              ),
              errorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      color: Colors.red
                  ),
                  borderRadius: BorderRadius.circular(15)
              ),
              focusedErrorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      color: Colors.red
                  ),
                  borderRadius: BorderRadius.circular(15)
              ),
              fillColor: const Color.fromRGBO(239, 239, 239, 1.0),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            textInputAction: TextInputAction.done,
            enabled: !loading,
            style: TextStyle(
                color: !loading ? Colors.black : const Color.fromRGBO(0, 0, 0, 0.5)
            ),
            controller: token,
            decoration: InputDecoration(
              errorText: error == '' ? null : error,
              filled: true,
              hintText: 'Enter token',
              prefixIcon: const Icon(Icons.lock_open),
              suffixIcon: loading ? Container(
                height: 15,
                width: 15,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 15),
                child: const SizedBox(
                  height: 15,
                  width: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.25,
                  ),
                ),
              ) : null,
              enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      style: BorderStyle.none
                  ),
                  borderRadius: BorderRadius.circular(15)
              ),
              focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      style: BorderStyle.none
                  ),
                  borderRadius: BorderRadius.circular(15)
              ),
              disabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      style: BorderStyle.none
                  ),
                  borderRadius: BorderRadius.circular(15)
              ),
              errorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      color: Colors.red
                  ),
                  borderRadius: BorderRadius.circular(15)
              ),
              focusedErrorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      color: Colors.red
                  ),
                  borderRadius: BorderRadius.circular(15)
              ),
              fillColor: const Color.fromRGBO(239, 239, 239, 1),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            width: 148,
            child: ElevatedButton(
              onPressed: loading ? null : () => tokentoClass(ref, context, username.text, token.text),
              child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith((states) {
                    return states.contains(MaterialState.disabled) ? const Color.fromRGBO(239, 239, 239, 1.0) : Theme.of(context).primaryColor;
                  }),
                  elevation: MaterialStateProperty.all(0),
                  shape: MaterialStateProperty.all(RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  )),
                  foregroundColor: MaterialStateProperty.resolveWith((states) {
                    return states.contains(MaterialState.disabled) ? const Color.fromRGBO(0, 0, 0, 0.5) : const Color.fromRGBO(51, 51, 51, 1);
                  }),
                  textStyle: MaterialStateProperty.all<TextStyle?>(
                      const TextStyle(fontWeight: FontWeight.w500, fontSize: 18))),
            ),
          ),
        ],
      ),
    );
  }
}


class ClassPageAdd extends ConsumerWidget {
  const ClassPageAdd({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset('assets/rsz_5283.jpg',width: 350),
        const Padding(
          padding: EdgeInsets.fromLTRB(60, 0, 60, 20),
          child: Text('How do you want to add your token?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 50,
              width: 148,
              child: ElevatedButton(
                onPressed: () => {
                  ref.read(currentPageProvider.state).state = 2
                },
                child: const Text('Sessiontoken', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color?>(
                        Theme.of(context).primaryColor),
                    elevation: MaterialStateProperty.all(0),
                    shape: MaterialStateProperty.all(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    )),
                    foregroundColor: MaterialStateProperty.all<Color?>(
                        const Color.fromRGBO(51, 51, 51, 1)),
                    textStyle: MaterialStateProperty.all<TextStyle?>(
                        const TextStyle(fontWeight: FontWeight.w500, fontSize: 18))),
              ),
            ),
            const SizedBox(width: 30),
            SizedBox(
              height: 50,
              width: 148,
              child: ElevatedButton(
                onPressed: () => {
                  ref.read(currentPageProvider.state).state = 2
                },
                child: const Text('Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color?>(
                        Theme.of(context).primaryColor),
                    elevation: MaterialStateProperty.all(0),
                    shape: MaterialStateProperty.all(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    )),
                    foregroundColor: MaterialStateProperty.all<Color?>(
                        const Color.fromRGBO(51, 51, 51, 1)),
                    textStyle: MaterialStateProperty.all<TextStyle?>(
                        const TextStyle(fontWeight: FontWeight.w500, fontSize: 18))),
              ),
            )
          ],
        )
      ],
    );
  }
}

Future refreshClasses(BuildContext context, WidgetRef ref) async {
  final http.Response response;
  try {
    response = await http.get(Uri.parse('http://45.81.232.194:3000/'+ref.read(currentClassProvider.state).state.id));
  }
  catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection Error"), backgroundColor: Colors.red, duration: Duration(seconds: 2)));
    return;
  }
  switch (response.statusCode) {
    case 200:
      ref.read(currentClassProvider.state).state = Apiresponse.fromJson(jsonDecode(response.body)).schoolClass!;
      break;
    case 400:
      context.go('/joinclass', extra: 'Class was deleted');
      break;
  }
  await Future.delayed(const Duration(milliseconds: 400));
}

class ClassPageBody extends HookConsumerWidget {
  const ClassPageBody({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect((){
      Timer timer = Timer.periodic(const Duration(seconds: 2),(Timer t)=>refreshClasses(context, ref));
      return timer.cancel;
    },[]);
    final currentClass = ref.watch(currentClassProvider);
    return currentClass.tokens.isEmpty ? Stack( //TODO Change to Animated
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 70),
          child: Text(currentClass.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20), textAlign: TextAlign.center),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset('assets/cardbox.jpg', width: 150,height: 150),
            const Text('Ooops... Nothing here', style: TextStyle(fontFamily: 'Gloria', fontSize: 24))
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 30, right: 80),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Add tokens here', style: TextStyle(fontFamily: 'Gloria')),
              Transform.rotate(
                angle: 12,
                child: Image.asset('assets/arrow.jpg', height: 80, width: 80),
              )
            ],
          ),
        )
      ],
    ) : Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 70),
          child: Text(currentClass.name,style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),textAlign: TextAlign.center,),
        ),
        Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: ScrollConfiguration(
                behavior: const ScrollBehavior(androidOverscrollIndicator: AndroidOverscrollIndicator.stretch),
                child: RefreshIndicator(
                  onRefresh: () => refreshClasses(context, ref),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      var dt = DateTime.fromMillisecondsSinceEpoch(currentClass.tokens[index].time);
                      var time = DateFormat('HH:mm - dd.MM.yyyy').format(dt);
                      return ExpansionTile(
                        title: Text(currentClass.tokens[index].name,style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                        subtitle: Text(time,style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,color: Theme.of(context).primaryColor)),
                        children: [
                          ListTile(leading: const Icon(Icons.access_time), title: Text(time)),
                          ListTile(
                              leading: const Icon(Icons.lock_open),
                              title: Text(currentClass.tokens[index].token),
                              trailing: IconButton(
                                  icon: const Icon(Icons.content_copy),
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(text: currentClass.tokens[index].token)).then((_){
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Token copied to clipboard")));
                                    });
                                  }
                              )
                          ),
                          ListTile(leading: const Icon(Icons.perm_identity), title: Text(currentClass.tokens[index].userid)),
                          ListTile(leading: const Icon(Icons.vpn_key_outlined), title: Text(currentClass.tokens[index].sessionkey)),
                          ListTile(leading: const Icon(Icons.fingerprint), title: Text(currentClass.tokens[index].id)),
                        ],
                      );
                    },
                    itemCount: currentClass.tokens.length,
                  ),
                ),
              ),
            )
        ),
      ],
    );
  }
}


class ClassSearchPage extends HookConsumerWidget {
  ClassSearchPage({Key? key, this.text='', this.initialerror=''}) : super(key: key);

  final String text;
  final String initialerror;
  String storedText = '';
  BuildContext? _context;
  final loadingProvider = StateProvider((ref) => false);
  String error = '';
  bool firstload = true;

  void fetchClass(String classid, WidgetRef ref) async {
    if (classid.isEmpty) {
      error = 'Classid can\'t be empty';
      return;
    }
    storedText = classid;
    final http.Response response;
    ref.read(loadingProvider.state).state = true;
    try {
      response = await http.get(Uri.parse('http://45.81.232.194:3000/'+classid));
    }
    catch (e) {
      error = 'Connection Error';
      ref.read(loadingProvider.state).state = false;
      return;
    }
    switch (response.statusCode) {
      case 200:
        Class schoolclass = Apiresponse.fromJson(jsonDecode(response.body)).schoolClass!;
        ref.read(currentClassProvider.state).state = schoolclass;
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setString('classid', schoolclass.id);
        prefs.setString('classname', schoolclass.name);
        _context!.go('/class');
        break;
      case 400:
        error = 'Can\'t find this class';
        break;
    }
    ref.read(loadingProvider.state).state = false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController()..text = storedText;
    text != '' ? controller.text = text : null;
    final loading = ref.watch(loadingProvider);
    _context = context;
    firstload == true ? WidgetsBinding.instance?.addPostFrameCallback((_) {
      initialerror != '' ? ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(initialerror), backgroundColor: Colors.red,)) : null;
      text != '' ? fetchClass(text, ref) : null;
    }) : null;
    firstload = false;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                children: [
                  TextSpan(
                      text: 'Join',
                      style: TextStyle(color: Theme.of(context).primaryColor)),
                  const TextSpan(
                    text: ' your class',
                  ),
                ],
              ),
            ),
            ),
            TextField(
              textInputAction: TextInputAction.search,
              enabled: !loading,
              controller: controller,
              style: TextStyle(
                color: !loading ? Colors.black : const Color.fromRGBO(0, 0, 0, 0.5)
              ),
              decoration: InputDecoration(
                filled: true,
                errorText: error == '' ? null : error,
                hintText: 'Enter classid',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: loading ? Container(
                  height: 15,
                  width: 15,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 15),
                  child: const SizedBox(
                    height: 15,
                    width: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.25,
                    ),
                  ),
                ) : null,
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    style: BorderStyle.none
                  ),
                  borderRadius: BorderRadius.circular(15)
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    style: BorderStyle.none
                  ),
                  borderRadius: BorderRadius.circular(15)
                ),
                disabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        style: BorderStyle.none
                    ),
                    borderRadius: BorderRadius.circular(15)
                ),
                errorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Colors.red
                    ),
                    borderRadius: BorderRadius.circular(15)
                ),
                focusedErrorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Colors.red
                    ),
                    borderRadius: BorderRadius.circular(15)
                ),
                fillColor: const Color.fromRGBO(239, 239, 239, 1),
              ),
              onSubmitted: (classid)=>fetchClass(classid, ref),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 15, right: 15),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Tip:',
                      style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600
                      ),
                    ),
                    const TextSpan(
                      text: ' You can also use your phone’s camera app to scan a QR-Code',
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            )
          ],
        ),
      )
    );
  }
}


class IntroductionPage extends StatefulWidget {
  const IntroductionPage({Key? key}) : super(key: key);

  @override
  _IntroductionPageState createState() => _IntroductionPageState();
}

class _IntroductionPageState extends State<IntroductionPage> {
  late Image ideas;
  late Image orga;
  late Image qrcode;
  late Image bugs;
  late Image future;

  @override
  void initState() {
    super.initState();
    ideas = Image.asset('assets/rsz_5440.jpg', width: 300, frameBuilder: (BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded) {
      if (wasSynchronouslyLoaded) {
        return child;
      }
      return AnimatedOpacity(
        opacity: frame == null ? 0 : 1,
        duration: const Duration(seconds: 1),
        curve: Curves.easeOut,
        child: child,
      );
    });
    orga = Image.asset('assets/Office workers organizing data storage.jpg', width: 300);
    qrcode = Image.asset('assets/11136_lq.jpg', width: 300);
    bugs = Image.asset('assets/10162.jpg', width: 300);
    future = Image.asset('assets/rsz_13205.jpg', width: 300);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(ideas.image, context);
    precacheImage(orga.image, context);
    precacheImage(qrcode.image, context);
    precacheImage(bugs.image, context);
    precacheImage(future.image, context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: IntroductionScreen(
          rawPages: [
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 200,
                    child: ideas,
                  ),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                      children: [
                        TextSpan(
                          text: 'New',
                          style: TextStyle(color: Theme.of(context).primaryColor),
                        ),
                        const TextSpan(
                          text: ' App Design',
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('We spent some time reworking the design of Token Manager and making it more continous', textAlign: TextAlign.center),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  orga,
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                      children: [
                        TextSpan(
                            text: 'Better',
                            style: TextStyle(color: Theme.of(context).primaryColor)),
                        const TextSpan(
                          text: ' Organization',
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('Tokens are now grouped into classes to make them easier to manage', textAlign: TextAlign.center),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  qrcode,
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                      children: [
                        TextSpan(
                            text: 'Join',
                            style: TextStyle(color: Theme.of(context).primaryColor)),
                        const TextSpan(
                          text: ' by QR-Code',
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('You can now join classes by just scanning a \nQR-Code with your default scanner', textAlign: TextAlign.center),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  bugs,
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                      children: [
                        TextSpan(
                            text: 'Fixed',
                            style: TextStyle(color: Theme.of(context).primaryColor)),
                        const TextSpan(
                          text: ' Bugs',
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('We looked at the problems of the first app\n and fixed every bug', textAlign: TextAlign.center),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  future,
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                      children: [
                        TextSpan(
                            text: 'Future',
                            style: TextStyle(color: Theme.of(context).primaryColor)),
                        const TextSpan(
                          text: ' Updates',
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('We have lots of secret things planned for future updates so keep an ear open whenever there\'s a new version', textAlign: TextAlign.center),
                  )
                ],
              ),
            ),
          ],
          showDoneButton: true,
          showNextButton: false,
          dotsDecorator: DotsDecorator(
            activeColor: Theme.of(context).primaryColor,
            size: const Size.square(9.0),
            activeSize: const Size(18.0, 9.0),
            activeShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
          ),
          color: Colors.black,
          skip: const Icon(
            Icons.arrow_back,
            color: Colors.transparent,
          ),
          done: const FadeIn(
              child: Text("Done", style: TextStyle(fontWeight: FontWeight.w600)),
              duration: Duration(milliseconds: 250),
              curve: Curves.easeIn
          ),
          onDone: () {
            context.go('/joinclass');
          },
        ));
  }
}


class StartPage extends StatelessWidget {
  const StartPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
      children: [
        Container(
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 40),
            alignment: Alignment.bottomCenter,
            child: const Button()),
        SizedBox(
            height: MediaQuery.of(context).size.height / 2,
            child: Center(
              child: Image.asset(
                'assets/Logo.png',
                fit: BoxFit.contain,
              ),
            ))
      ],
    ));
  }
}

class Button extends StatelessWidget {
  const Button({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      width: 275,
      child: ElevatedButton(
        onPressed: () => {
          context.go('/introduction')
        },
        child: const Text('Get started'),
        style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all<Color?>(
                Theme.of(context).primaryColor),
            elevation: MaterialStateProperty.all(0),
            shape: MaterialStateProperty.all(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            )),
            foregroundColor: MaterialStateProperty.all<Color?>(
                const Color.fromRGBO(51, 51, 51, 1)),
            textStyle: MaterialStateProperty.all<TextStyle?>(
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 18))),
      ),
    );
  }
}