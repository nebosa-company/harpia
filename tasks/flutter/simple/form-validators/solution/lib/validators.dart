/// Field validators for the signup form.

String? validateUsername(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) {
    return 'Username is required';
  }
  if (v.length < 3) {
    return 'Username must be at least 3 characters';
  }
  if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(v)) {
    return 'Username may only contain letters, numbers, and underscores';
  }
  return null;
}

String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) {
    return 'Email is required';
  }
  if (!RegExp(r'^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$').hasMatch(v)) {
    return 'Enter a valid email address';
  }
  return null;
}

String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) {
    return 'Password is required';
  }
  if (v.length < 8) {
    return 'Password must be at least 8 characters';
  }
  if (!v.contains(RegExp(r'\d'))) {
    return 'Password must contain a number';
  }
  return null;
}
