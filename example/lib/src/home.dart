import 'dart:convert';

import 'package:example/src/read_only_view.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zefyrka/zefyrka.dart';

import 'forms_decorated_field.dart';
import 'layout.dart';
import 'layout_expanded.dart';
import 'layout_scrollable.dart';
import 'settings.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LimitedZefyrController? _controller;
  final FocusNode _focusNode = FocusNode();

  Settings? _settings;

  //[Sayed Documentation] Character limit for the editor
  static const int _maxCharacterLimit = 1000;
  int _currentCharacterCount = 0;

  void _handleSettingsLoaded(Settings value) {
    setState(() {
      _settings = value;
      _loadFromAssets();
    });
  }

  @override
  void initState() {
    super.initState();
    Settings.load().then(_handleSettingsLoaded);
  }

  //[Sayed Documentation] Load initial data with styled content
  Future<void> _loadFromAssets() async {
    try {
      final result = await rootBundle.loadString('assets/welcome.note');
      final doc = NotusDocument.fromJson(jsonDecode(result));
      setState(() {
        _controller = LimitedZefyrController(
          doc,
          maxCharacterLimit: _maxCharacterLimit,
          onCharacterCountChanged: _updateCharacterCount,
          onLimitExceeded: _showLimitExceededDialog,
        );
        _updateCharacterCount();
      });
    } catch (error) {
      //[Sayed Documentation] Create empty document to start with no text
      final emptyDoc = NotusDocument();
      setState(() {
        _controller = LimitedZefyrController(
          emptyDoc,
          maxCharacterLimit: _maxCharacterLimit,
          onCharacterCountChanged: _updateCharacterCount,
          onLimitExceeded: _showLimitExceededDialog,
        );
        _updateCharacterCount();
      });
    }
  }

  //[Sayed Documentation] Update character count and check limit
  void _updateCharacterCount() {
    if (_controller != null) {
      final plainText = _controller!.document.toPlainText();
      setState(() {
        _currentCharacterCount = plainText.length;
      });

      //[Sayed Documentation] Print rich text content to console (as it would be sent to backend)
      if (plainText.isNotEmpty) {
        print('=== RICH TEXT CONTENT (JSON) ===');
        print(jsonEncode(_controller!.document));
        print('=== END RICH TEXT CONTENT ===');

        //[Sayed Documentation] Also print plain text for reference
        print('=== PLAIN TEXT CONTENT ===');
        print(plainText);
        print('=== END PLAIN TEXT CONTENT ===');
      }
    }
  }

  //[Sayed Documentation] Check if character limit is exceeded
  bool _isCharacterLimitExceeded() {
    return _currentCharacterCount > _maxCharacterLimit;
  }

  //[Sayed Documentation] Get character count color based on limit
  Color _getCharacterCountColor() {
    if (_isCharacterLimitExceeded()) {
      return Colors.red;
    } else if (_currentCharacterCount > _maxCharacterLimit * 0.8) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  Future<void> _save() async {
    final fs = LocalFileSystem();
    final file = fs.directory(_settings!.assetsPath).childFile('welcome.note');
    final data = jsonEncode(_controller!.document);
    await file.writeAsString(data);
  }

  @override
  Widget build(BuildContext context) {
    if (_settings == null || _controller == null) {
      return Scaffold(body: Center(child: Text('Loading...')));
    }

    return SettingsProvider(
      settings: _settings,
      child: PageLayout(
        appBar: AppBar(
          backgroundColor: Colors.grey.shade800,
          elevation: 0,
          centerTitle: false,
          title: Text(
            'Zefyr',
            style: GoogleFonts.fondamento(color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.settings, size: 16),
              onPressed: _showSettings,
            ),
            if (_settings!.assetsPath!.isNotEmpty)
              IconButton(
                icon: Icon(Icons.save, size: 16),
                onPressed: _save,
              )
          ],
        ),
        menuBar: Material(
          color: Colors.grey.shade800,
          child: _buildMenuBar(context),
        ),
        body: _buildWelcomeEditor(context),
      ),
    );
  }

  void _showSettings() async {
    final result = await showSettingsDialog(context, _settings);
    if (mounted && result != null) {
      setState(() {
        _settings = result;
      });
    }
  }

  Widget _buildMenuBar(BuildContext context) {
    final headerStyle = TextStyle(
        fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold);
    final itemStyle = TextStyle(color: Colors.white);
    return ListView(
      children: [
        ListTile(
          title: Text('BASIC EXAMPLES', style: headerStyle),
          // dense: true,
          visualDensity: VisualDensity.compact,
        ),
        ListTile(
          title: Text('¶   Read only view', style: itemStyle),
          dense: true,
          visualDensity: VisualDensity.compact,
          onTap: _readOnlyView,
        ),
        ListTile(
          title: Text('LAYOUT EXAMPLES', style: headerStyle),
          // dense: true,
          visualDensity: VisualDensity.compact,
        ),
        ListTile(
          title: Text('¶   Expandable', style: itemStyle),
          dense: true,
          visualDensity: VisualDensity.compact,
          onTap: _expanded,
        ),
        ListTile(
          title: Text('¶   Custom scrollable', style: itemStyle),
          dense: true,
          visualDensity: VisualDensity.compact,
          onTap: _scrollable,
        ),
        ListTile(
          title: Text('FORMS AND FIELDS EXAMPLES', style: headerStyle),
          // dense: true,
          visualDensity: VisualDensity.compact,
        ),
        ListTile(
          title: Text('¶   Decorated field', style: itemStyle),
          dense: true,
          visualDensity: VisualDensity.compact,
          onTap: _decoratedField,
        ),
      ],
    );
  }

  Widget _buildWelcomeEditor(BuildContext context) {
    return Column(
      children: [
        ZefyrToolbar.basic(
          controller: _controller!,
        ),
        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        //[Sayed Documentation] Character count display
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          color: Colors.grey.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Character Count: $_currentCharacterCount/$_maxCharacterLimit',
                style: TextStyle(
                  color: _getCharacterCountColor(),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_isCharacterLimitExceeded())
                Icon(
                  Icons.warning,
                  color: Colors.red,
                  size: 16,
                ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.only(left: 16.0, right: 16.0),
            child: ZefyrEditor(
              controller: _controller!,
              focusNode: _focusNode,
              clipboardController: _createLimitedClipboardController(),
              autofocus: true,
              // readOnly: true,
              // padding: EdgeInsets.only(left: 16, right: 16),
              onLaunchUrl: _launchUrl,
            ),
          ),
        ),
      ],
    );
  }

  //[Sayed Documentation] Create a clipboard controller that respects character limits
  ClipboardController _createLimitedClipboardController() {
    return LimitedClipboardController(
      maxCharacterLimit: _maxCharacterLimit,
      onLimitExceeded: _showLimitExceededDialog,
    );
  }

  //[Sayed Documentation] Show dialog when character limit is exceeded
  void _showLimitExceededDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Character Limit Exceeded'),
          content: Text(
              'The content you are trying to add would exceed the maximum character limit of $_maxCharacterLimit characters.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _launchUrl(Uri url) async {
    final result = await canLaunchUrl(url);
    if (result) {
      await launchUrl(url);
    }
  }

  void _expanded() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => SettingsProvider(
          settings: _settings,
          child: ExpandedLayout(),
        ),
      ),
    );
  }

  void _readOnlyView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => SettingsProvider(
          settings: _settings,
          child: ReadOnlyView(),
        ),
      ),
    );
  }

  void _scrollable() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => SettingsProvider(
          settings: _settings,
          child: ScrollableLayout(),
        ),
      ),
    );
  }

  void _decoratedField() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => SettingsProvider(
          settings: _settings,
          child: DecoratedFieldDemo(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

//[Sayed Documentation] Custom ZefyrController that enforces character limits
class LimitedZefyrController extends ZefyrController {
  final int maxCharacterLimit;
  final VoidCallback onCharacterCountChanged;
  final VoidCallback onLimitExceeded;

  LimitedZefyrController(
    NotusDocument document, {
    required this.maxCharacterLimit,
    required this.onCharacterCountChanged,
    required this.onLimitExceeded,
  }) : super(document) {
    // Add listener to track character count changes
    addListener(_handleCharacterCountChange);
  }

  //[Sayed Documentation] Handle character count changes
  void _handleCharacterCountChange() {
    onCharacterCountChanged();
  }

  @override
  void replaceText(int index, int length, Object? data,
      {TextSelection? selection}) {
    if (data is String) {
      //[Sayed Documentation] Check if the new content would exceed the character limit
      final currentText = document.toPlainText();
      final selectedTextLength = this.selection.end - this.selection.start;
      final newTextLength =
          currentText.length - selectedTextLength + data.length;

      if (newTextLength > maxCharacterLimit) {
        onLimitExceeded();
        return;
      }
    }

    // Proceed with normal text replacement
    super.replaceText(index, length, data, selection: selection);
  }

  @override
  void dispose() {
    removeListener(_handleCharacterCountChange);
    super.dispose();
  }
}

//[Sayed Documentation] Custom clipboard controller that enforces character limits
class LimitedClipboardController implements ClipboardController {
  final int maxCharacterLimit;
  final VoidCallback onLimitExceeded;

  LimitedClipboardController({
    required this.maxCharacterLimit,
    required this.onLimitExceeded,
  });

  @override
  void copy(ZefyrController controller, String plainText) {
    if (!controller.selection.isCollapsed) {
      // ignore: unawaited_futures
      Clipboard.setData(
          ClipboardData(text: controller.selection.textInside(plainText)));
    }
  }

  @override
  TextEditingValue? cut(ZefyrController controller, String plainText) {
    if (!controller.selection.isCollapsed) {
      final data = controller.selection.textInside(plainText);
      // ignore: unawaited_futures
      Clipboard.setData(ClipboardData(text: data));

      controller.replaceText(
        controller.selection.start,
        data.length,
        '',
        selection: TextSelection.collapsed(offset: controller.selection.start),
      );

      return TextEditingValue(
        text: controller.selection.textBefore(plainText) +
            controller.selection.textAfter(plainText),
        selection: TextSelection.collapsed(offset: controller.selection.start),
      );
    }
    return null;
  }

  @override
  Future<void> paste(
      ZefyrController controller, TextEditingValue textEditingValue) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      final currentText = controller.document.toPlainText();
      final selection = controller.selection;
      final selectedTextLength = selection.end - selection.start;
      final newTextLength =
          currentText.length - selectedTextLength + data.text!.length;

      if (newTextLength > maxCharacterLimit) {
        onLimitExceeded();
        return;
      }

      // Proceed with normal paste operation
      final length = controller.selection.end - controller.selection.start;
      controller.replaceText(
        controller.selection.start,
        length,
        data.text!,
        selection: TextSelection.collapsed(
            offset: controller.selection.start + data.text!.length),
      );
    }
  }
}
