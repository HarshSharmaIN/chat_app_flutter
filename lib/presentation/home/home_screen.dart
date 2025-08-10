import 'package:chat_app/data/repositories/auth_repository.dart';
import 'package:chat_app/data/repositories/chat_repository.dart';
import 'package:chat_app/data/repositories/contact_repository.dart';
import 'package:chat_app/config/theme/app_theme.dart';
import 'package:chat_app/data/services/service_locator.dart';
import 'package:chat_app/logic/cubits/auth/auth_cubit.dart';
import 'package:chat_app/presentation/chat/chat_message_sceen.dart';
import 'package:chat_app/presentation/screens/auth/login_screen.dart';
import 'package:chat_app/presentation/widgets/chat_list_tile.dart';
import 'package:chat_app/presentation/widgets/animated_list_tile.dart';
import 'package:chat_app/router/app_router.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late final ContactRepository _contactRepository;
  late final ChatRepository _chatRepository;
  late final String _currentUserId;

  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _contactRepository = getIt<ContactRepository>();
    _chatRepository = getIt<ChatRepository>();
    _currentUserId = getIt<AuthRepository>().currentuser?.uid ?? "";
    
    _fabController = AnimationController(
      duration: AppTheme.normalAnimation,
      vsync: this,
    );
    
    _fabAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabController,
      curve: AppTheme.bounceCurve,
    ));
    
    _startFabAnimation();
  }

  void _startFabAnimation() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      _fabController.forward();
    }
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _showContactsList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Select Contact",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _contactRepository.getRegisteredContacts(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Error loading contacts",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        ),
                      );
                    }

                    final contacts = snapshot.data!;
                    if (contacts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.contacts_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No contacts found",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Invite friends to join ChatApp",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        return AnimatedListTile(
                          animationDelay: index * 100,
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            child: Text(
                              contact["name"][0].toUpperCase(),
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          title: Text(
                            contact["name"],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            "Tap to start chatting",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            getIt<AppRouter>().push(
                              ChatMessageSceen(
                                receiverId: contact['id'],
                                receiverName: contact['name'],
                                currentUserName:
                                    getIt<AuthRepository>()
                                        .currentuser
                                        ?.displayName ??
                                    "You",
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Messages",
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryColor,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () async {
                await getIt<AuthCubit>().signOut();
                getIt<AppRouter>().pushAndRemoveUntil(const LoginScreen());
              },
              icon: const Icon(
                Icons.logout_rounded,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: StreamBuilder(
            stream: _chatRepository.getChatRooms(_currentUserId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                print(snapshot.error);
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Something went wrong",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                );
              }
              final chats = snapshot.data!;
              if (chats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "No conversations yet",
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Start a new conversation by tapping the + button",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(top: 20),
                itemCount: chats.length,
                itemBuilder: (content, index) {
                  final chat = chats[index];
                  return ChatListTile(
                    chat: chat,
                    currentUserId: _currentUserId,
                    animationDelay: index * 100,
                    onTap: () {
                      final otherUserId = chat.participants.firstWhere(
                        (id) => id != _currentUserId,
                      );
                      final otherUserName =
                          chat.participantsName![otherUserId] ?? "Unknown";
                      getIt<AppRouter>().push(
                        ChatMessageSceen(
                          receiverId: otherUserId,
                          receiverName: otherUserName,
                          currentUserName:
                              getIt<AuthRepository>().currentuser?.displayName ??
                              "You",
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton(
          onPressed: () => _showContactsList(context),
          backgroundColor: AppTheme.primaryColor,
          elevation: 8,
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}
