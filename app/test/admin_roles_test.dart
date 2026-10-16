import 'package:flutter_test/flutter_test.dart';

import 'package:ycp_store/src/data/models.dart';
import 'package:ycp_store/src/data/order_repository.dart';

void main() {
  test('StaffMember reads the database role word and the name', () {
    final member = StaffMember.fromJson({
      'id': 'u-1',
      'display_name': 'Chanpenh',
      'role': 'admin',
    });

    expect(member.displayName, 'Chanpenh');
    expect(member.role, 'admin');
    expect(member.isAdmin, isTrue);
  });

  test('a missing name is empty, a missing role is customer', () {
    final member = StaffMember.fromJson({'id': 'u-2'});

    expect(member.displayName, '');
    expect(member.role, 'customer');
    expect(member.isAdmin, isFalse);
  });

  test('staff can run the admin screens but cannot manage roles', () {
    const staff = Profile(
      id: 's',
      walletBalance: 0,
      coins: 0,
      displayName: 'Staff',
      role: 'staff',
    );

    expect(staff.isStaff, isTrue);
    expect(staff.isAdmin, isFalse);
  });

  test('admin is both staff and admin', () {
    const admin = Profile(
      id: 'a',
      walletBalance: 0,
      coins: 0,
      displayName: 'Admin',
      role: 'admin',
    );

    expect(admin.isStaff, isTrue);
    expect(admin.isAdmin, isTrue);
  });
}
