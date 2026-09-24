import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearGradient, MediaQuery, Radius, BorderRadius, BoxDecoration, Column, Expanded, Center, ListView, Padding, EdgeInsets, Text, TextStyle, FontWeight, Container;
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets.dart';
import 'services/coach_service.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _noApiKey = false;

  @override
  void initState() {
    super.initState();
    _initCoach();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initCoach() async {
    setState(() => _isLoading = true);
    if (CoachService().chatHistory.isEmpty) {
      await CoachService().initializeChat();
    }
    setState(() {
      _isLoading = false;
      _noApiKey = CoachService().chatHistory.isEmpty;
    });
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _focusNode.unfocus();
    setState(() {
      _msgCtrl.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    await CoachService().sendMessage(text);
    if (mounted) setState(() => _isLoading = false);
    _scrollToBottom();
  }

  Future<void> _showHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final archives = prefs.getStringList('coach_archives') ?? [];
    
    if (!mounted) return;
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoActionSheetAction(
          onPressed: () {},
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Past Conversations', style: TextStyle(color: kTextPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        child: const Icon(CupertinoIcons.xmark, color: kTextMuted),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: archives.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('💭', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 16),
                              const Text('No saved conversations yet', style: TextStyle(color: kTextMuted, fontSize: 14)),
                              const SizedBox(height: 8),
                              const Text('Tap "New" to save your current chat', style: TextStyle(color: kTextSecondary, fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: archives.length,
                          itemBuilder: (context, index) {
                            final reversedIndex = archives.length - 1 - index;
                            final archive = archives[reversedIndex];
                            final lines = archive.split('\n');
                            final header = lines.first; // Contains date
                            final sessionId = header.replaceAll('--- Session on ', '').replaceAll(' ---', '');
                            
                            // Extract summary: first user message + message count
                            String summary = 'No messages';
                            int messageCount = 0;
                            String? firstUserMsg;
                            String? lastAiMsg;
                            
                            for (var i = 1; i < lines.length; i++) {
                              final line = lines[i].trim();
                              if (line.isEmpty) continue;
                              messageCount++;
                              
                              if (firstUserMsg == null && line.startsWith('User:')) {
                                firstUserMsg = line.substring(5).trim();
                              }
                              if (line.startsWith('Mann:')) {
                                lastAiMsg = line.substring(5).trim();
                              }
                            }
                            
                            if (firstUserMsg != null) {
                              summary = firstUserMsg.length > 60 
                                ? '${firstUserMsg.substring(0, 60)}...' 
                                : firstUserMsg;
                            }
                            
                            return GestureDetector(
                              onTap: () async {
                                await CoachService().resumeArchivedConversation(sessionId);
                                if (mounted) {
                                  Navigator.pop(context);
                                  setState(() {}); // Refresh to show loaded conversation
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: kSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: kBorder, width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            header,
                                            style: const TextStyle(color: kNeon, fontSize: 11, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: kNeon.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '$messageCount msgs',
                                            style: const TextStyle(color: kNeon, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      summary,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: kTextPrimary, fontSize: 13, height: 1.3),
                                    ),
                                    if (lastAiMsg != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        '↳ ${lastAiMsg.length > 50 ? '${lastAiMsg.substring(0, 50)}...' : lastAiMsg}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: kTextSecondary, fontSize: 11, fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _clearChat() async {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('New Conversation?'),
        content: const Text('This will clear the screen and start a fresh chat. Your past conversation will be saved for Mann to remember.'),
        actions: [
          CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Start New'),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              await CoachService().archiveCurrentChat();
              if (mounted) setState(() => _isLoading = false);
              _scrollToBottom();
            },
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = CoachService().chatHistory;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: CupertinoPageScaffold(
        backgroundColor: kBg,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: kBg.withValues(alpha: 0.8),
          border: null,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showHistory,
            child: const Text('History', style: TextStyle(color: kTextMuted, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          middle: const Text('MANN', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w900, letterSpacing: 2)),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _clearChat,
            child: const Text('New', style: TextStyle(color: kNeon, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // No API key banner
              if (_noApiKey)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kAmber),
                  ),
                  child: const Row(children: [
                    Text('⚙️ ', style: TextStyle(fontSize: 18)),
                    Expanded(
                      child: Text(
                        'Add your Gemini API key in Profile to enable Mann.',
                        style: TextStyle(color: kAmber, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]),
                ),

              // Messages
              Expanded(
                child: history.isEmpty && _isLoading
                    ? const Center(child: CupertinoActivityIndicator())
                    : history.isEmpty
                        ? const Center(child: Text('Connecting to Mann...', style: TextStyle(color: kTextMuted)))
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 140), // Nav bar padding
                            itemCount: history.length + (_isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Typing indicator
                              if (_isLoading && index == history.length) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: kSurface,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(20), topRight: Radius.circular(20),
                                        bottomRight: Radius.circular(20), bottomLeft: Radius.circular(4),
                                      ),
                                      border: Border.all(color: kBorder),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CupertinoActivityIndicator(color: kTeal, radius: 8),
                                        SizedBox(width: 10),
                                        Text('Mann is typing...', style: TextStyle(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              final msg = history[index];
                              final isAi = msg.role == 'ai';
                              final isFirst = index == 0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                  children: [
                                    if (isAi && isFirst)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 24, height: 24,
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(colors: [kTeal, kNeon]),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Center(child: Text('M', style: TextStyle(color: kBg, fontSize: 12, fontWeight: FontWeight.w900))),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text('MANN', style: TextStyle(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                          ],
                                        ),
                                      ),
                                    Container(
                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isAi ? kSurface : kNeon.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(20),
                                          topRight: const Radius.circular(20),
                                          bottomLeft: Radius.circular(isAi ? 4 : 20),
                                          bottomRight: Radius.circular(isAi ? 20 : 4),
                                        ),
                                        border: Border.all(color: isAi ? kBorder : kNeon.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        msg.text,
                                        style: TextStyle(
                                          color: isAi ? kTextPrimary : kNeon,
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),

              // Input bar
              Container(
                padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 140), // Handle nav bar spacing if not focused
                decoration: const BoxDecoration(
                  color: kSurface,
                  border: Border(top: BorderSide(color: kBorder2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        decoration: BoxDecoration(
                          color: kBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: kBorder),
                        ),
                        child: CupertinoTextField(
                          controller: _msgCtrl,
                          focusNode: _focusNode,
                          placeholder: 'Ask Mann...',
                          placeholderStyle: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w600),
                          style: const TextStyle(color: kTextPrimary, fontSize: 14),
                          decoration: const BoxDecoration(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          maxLines: 5,
                          minLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _send,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: _isLoading ? kSurface2 : kNeon,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isLoading ? CupertinoIcons.ellipsis : CupertinoIcons.arrow_up,
                          color: _isLoading ? kTextMuted : kBg,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
