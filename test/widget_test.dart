import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

void main() => runApp(NoteApp());

class NoteApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Note App with Folders',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: NoteListPage(),
    );
  }
}

class NoteListPage extends StatefulWidget {
  @override
  _NoteListPageState createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  late Database database;
  List<Map<String, dynamic>> notes = [];
  List<String> folders = [];
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initializeDatabase();
  }

  Future<void> initializeDatabase() async {
    final dbPath = await getDatabasesPath();
    database = await openDatabase(
      join(dbPath, 'notes.db'),
      version: 3,
      onCreate: (db, version) {
        db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY, 
            title TEXT, 
            content TEXT, 
            folder TEXT, 
            created_at TEXT, 
            updated_at TEXT
          )
        ''');
        db.execute('''
          CREATE TABLE folders(
            id INTEGER PRIMARY KEY, 
            name TEXT UNIQUE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) {
        if (oldVersion < 3) {
          db.execute('ALTER TABLE notes ADD COLUMN folder TEXT DEFAULT NULL');
          db.execute('''
            CREATE TABLE folders(
              id INTEGER PRIMARY KEY, 
              name TEXT UNIQUE
            )
          ''');
        }
      },
    );
    fetchNotes();
    fetchFolders();
  }

  Future<void> fetchNotes([String? folder]) async {
    final data = await database.query(
      'notes',
      where: folder != null ? 'folder = ? AND (title LIKE ? OR content LIKE ?)' : '(title LIKE ? OR content LIKE ?)',
      whereArgs: folder != null ? [folder, '%$searchQuery%', '%$searchQuery%'] : ['%$searchQuery%', '%$searchQuery%'],
    );
    setState(() {
      notes = data;
    });
  }

  Future<void> fetchFolders() async {
    final data = await database.query('folders');
    setState(() {
      folders = data.map((e) => e['name'] as String).toList();
    });
  }

  Future<void> addNote(String title, String content, [String? folder]) async {
    final currentTime = _formatDateTime(DateTime.now());
    await database.insert('notes', {
      'title': title,
      'content': content,
      'folder': folder,
      'created_at': currentTime,
      'updated_at': currentTime,
    });
    fetchNotes();
  }

  Future<void> updateNote(int id, String title, String content) async {
    final currentTime = _formatDateTime(DateTime.now());
    await database.update(
      'notes',
      {
        'title': title,
        'content': content,
        'updated_at': currentTime,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    fetchNotes();
  }

  Future<void> deleteNoteById(int id) async {
    await database.delete('notes', where: 'id = ?', whereArgs: [id]);
    fetchNotes();
  }

  Future<void> addFolder(String name) async {
    try {
      await database.insert('folders', {'name': name});
      fetchFolders();
    } catch (e) {
      // Handle unique constraint violation
    }
  }

  Future<void> updateFolder(int folderId, String newName) async {
    try {
      await database.update(
        'folders',
        {'name': newName},
        where: 'id = ?',
        whereArgs: [folderId],
      );
      fetchFolders();  // Lấy lại danh sách thư mục sau khi cập nhật
    } catch (e) {
      // Xử lý lỗi nếu có
      print("Error updating folder: $e");
    }
  }

  Future<void> deleteFolderById(int folderId) async {
    final folderName = folders[folderId - 1];
    await database.update(
      'notes',
      {'folder': null},
      where: 'folder = ?',
      whereArgs: [folderName],
    );
    await database.delete('folders', where: 'id = ?', whereArgs: [folderId]);
    fetchFolders();
  }

  String _formatDateTime(DateTime dateTime) {
    final formattedTime = DateFormat('HH:mm').format(dateTime);
    final formattedDate = DateFormat('dd/MM/yyyy').format(dateTime);
    return '$formattedTime, $formattedDate';
  }

  void showAddNoteDialog([Map<String, dynamic>? existingNote]) {
    String title = existingNote != null ? existingNote['title'] : '';
    String content = existingNote != null ? existingNote['content'] : '';
    String? folder = existingNote != null ? existingNote['folder'] : null;

    showDialog(
      context: this.context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(existingNote != null ? 'Chỉnh sửa ghi chú' : 'Thêm ghi chú'),
          content: SingleChildScrollView( // Thêm SingleChildScrollView để cuộn khi cần
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: folder,
                  items: folders
                      .map((folder) => DropdownMenuItem(
                    value: folder,
                    child: Text(folder),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      folder = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Thư mục',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: TextEditingController(text: title),
                  decoration: InputDecoration(
                    labelText: 'Tiêu đề',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                  onChanged: (value) => title = value,
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: TextEditingController(text: content),
                  decoration: InputDecoration(
                    labelText: 'Nội dung',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                  maxLines: 6,
                  onChanged: (value) => content = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (title.isNotEmpty && content.isNotEmpty) {
                  if (existingNote != null) {
                    updateNote(existingNote['id'], title, content);
                  } else {
                    addNote(title, content, folder);
                  }
                  Navigator.pop(context);
                }
              },
              child: Text(existingNote != null ? 'Cập nhật' : 'Thêm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
            ),
          ],
        );
      },
    );
  }

  void showAddFolderDialog() {
    String folderName = '';
    showDialog(
      context: this.context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Thêm thư mục mới'),
          content: TextField(
            decoration: InputDecoration(
              labelText: 'Tên thư mục',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.grey[200],
            ),
            onChanged: (value) => folderName = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (folderName.isNotEmpty) {
                  addFolder(folderName);
                  Navigator.pop(context);
                }
              },
              child: Text('Thêm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm ghi chú...',
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  searchController.clear();
                  searchQuery = '';
                  fetchNotes();
                });
              },
            ),
          ),
          onChanged: (value) {
            setState(() {
              searchQuery = value;
              fetchNotes();
            });
          },
        ),
      ),
      body: ListView.builder(
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return ListTile(
            title: Text(note['title']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note['content']),
                SizedBox(height: 4),
                Text(
                  'Ngày tạo: ${note['created_at']}',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                Text(
                  'Cập nhật: ${note['updated_at']}',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            onTap: () => showAddNoteDialog(note),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => deleteNoteById(note['id']),
            ),
          );
        },
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              title: Text('Thư mục'),
              trailing: Icon(Icons.folder),
              onTap: () {
                Navigator.pop(context);
                showAddFolderDialog();
              },
            ),
            ListView.builder(
              shrinkWrap: true,
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return ListTile(
                  title: Text(folder),
                  onTap: () {
                    Navigator.pop(context);
                    fetchNotes(folder);
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          TextEditingController folderController = TextEditingController(text: folder);
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Chỉnh sửa thư mục'),
                                content: TextField(
                                  controller: folderController,
                                  decoration: InputDecoration(
                                    labelText: 'Tên thư mục',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('Hủy'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (folderController.text.isNotEmpty) {
                                        updateFolder(index + 1, folderController.text);
                                        Navigator.pop(context);
                                      }
                                    },
                                    child: Text('Cập nhật'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          deleteFolderById(index + 1);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
