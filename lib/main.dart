import 'package:chat_app/config/theme/app_theme.dart';
import 'package:chat_app/data/repositories/chat_repository.dart';
import 'package:chat_app/data/services/service_locator.dart';
import 'package:chat_app/data/services/stream_token_service.dart';
import 'package:chat_app/logic/cubits/auth/auth_cubit.dart';
import 'package:chat_app/logic/cubits/auth/auth_state.dart';
import 'package:chat_app/logic/observer/app_life_cycle_observer.dart';
import 'package:chat_app/presentation/splash/splash_screen.dart';
import 'package:chat_app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

void main() async {
  await setUpServicelocator();
  await dotenv.load();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLifeCycleObserver _lifeCycleObserver;

  @override
  void initState() {
    super.initState();
    getIt<AuthCubit>().stream.listen((state) async {
      if (state.status == AuthStatus.authenticated && state.user != null) {
        final token = await StreamTokenService.generateUserToken(
          userId: state.user!.uid,
        );
        final client = StreamVideo(
          dotenv.get("STREAM_API_KEY"),
          user: User.regular(
            userId: state.user!.uid,
            name: state.user!.fullName,
          ),
          userToken: token,
        );
        _lifeCycleObserver = AppLifeCycleObserver(
          userId: state.user!.uid,
          chatRepository: getIt<ChatRepository>(),
        );
        WidgetsBinding.instance.addObserver(_lifeCycleObserver);
      } else if (state.status == AuthStatus.unauthenticated) {
        WidgetsBinding.instance.removeObserver(_lifeCycleObserver);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: MaterialApp(
        title: 'Chat App',
        theme: AppTheme.lightTheme,
        navigatorKey: getIt<AppRouter>().navigatorKey,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      ),
    );
  }
}
