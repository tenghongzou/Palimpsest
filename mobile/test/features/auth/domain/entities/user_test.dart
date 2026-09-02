import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/features/auth/domain/entities/user.dart';

void main() {
  group('User', () {
    test('creation with required fields', () {
      const user = User(
        id: 'u-001',
        username: 'testuser',
        email: 'test@example.com',
        nickname: 'Test',
      );

      expect(user.id, 'u-001');
      expect(user.username, 'testuser');
      expect(user.email, 'test@example.com');
      expect(user.nickname, 'Test');
    });

    test('default role is reader', () {
      const user = User(
        id: 'u-001',
        username: 'testuser',
        email: 'test@example.com',
        nickname: 'Test',
      );

      expect(user.role, 'reader');
    });

    test('default languagePref is zh-TW', () {
      const user = User(
        id: 'u-001',
        username: 'testuser',
        email: 'test@example.com',
        nickname: 'Test',
      );

      expect(user.languagePref, 'zh-TW');
    });

    test('optional avatarUrl is null by default', () {
      const user = User(
        id: 'u-001',
        username: 'testuser',
        email: 'test@example.com',
        nickname: 'Test',
      );

      expect(user.avatarUrl, isNull);
    });

    test('creation with all fields set', () {
      const user = User(
        id: 'u-002',
        username: 'admin',
        email: 'admin@example.com',
        nickname: 'Admin User',
        avatarUrl: 'https://cdn.example.com/avatar.png',
        role: 'admin',
        languagePref: 'zh-CN',
      );

      expect(user.id, 'u-002');
      expect(user.username, 'admin');
      expect(user.email, 'admin@example.com');
      expect(user.nickname, 'Admin User');
      expect(user.avatarUrl, 'https://cdn.example.com/avatar.png');
      expect(user.role, 'admin');
      expect(user.languagePref, 'zh-CN');
    });
  });
}
