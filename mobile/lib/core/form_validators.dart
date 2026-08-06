class FormValidators {
  const FormValidators._();

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String normalizeSingleLine(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  static String normalizeMultiline(String value) => value.trim();

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static String? departmentName(String? value) {
    final normalized = normalizeSingleLine(value ?? '');
    if (normalized.isEmpty) {
      return 'Ingrese el nombre del departamento.';
    }
    if (normalized.length < 2) {
      return 'El nombre debe tener al menos 2 caracteres.';
    }
    if (normalized.length > 120) {
      return 'El nombre no puede superar 120 caracteres.';
    }
    return null;
  }

  static String? personName(String? value) {
    final normalized = normalizeSingleLine(value ?? '');
    if (normalized.isEmpty) {
      return 'Ingrese el nombre del usuario.';
    }
    if (normalized.length < 2) {
      return 'El nombre debe tener al menos 2 caracteres.';
    }
    if (normalized.length > 120) {
      return 'El nombre no puede superar 120 caracteres.';
    }
    return null;
  }

  static String? taskTitle(String? value) {
    final normalized = normalizeSingleLine(value ?? '');
    if (normalized.isEmpty) {
      return 'Ingrese el título de la tarea.';
    }
    if (normalized.length < 2) {
      return 'El título debe tener al menos 2 caracteres.';
    }
    if (normalized.length > 150) {
      return 'El título no puede superar 150 caracteres.';
    }
    return null;
  }

  static String? optionalDescription(String? value) {
    final normalized = normalizeMultiline(value ?? '');
    if (normalized.length > 3000) {
      return 'La descripción no puede superar 3000 caracteres.';
    }
    return null;
  }

  static String? email(String? value) {
    final normalized = normalizeEmail(value ?? '');
    if (normalized.isEmpty) {
      return 'Ingrese el correo electrónico.';
    }
    if (normalized.length > 254 || !_emailPattern.hasMatch(normalized)) {
      return 'Ingrese un correo electrónico válido.';
    }
    return null;
  }

  static String? password(
    String? value, {
    bool optional = false,
    int minLength = 6,
  }) {
    final password = value ?? '';
    if (optional && password.isEmpty) {
      return null;
    }
    if (password.trim().isEmpty) {
      return optional
          ? 'La contraseña no puede contener solo espacios.'
          : 'Ingrese la contraseña.';
    }
    if (password.length < minLength) {
      return 'La contraseña debe tener al menos $minLength caracteres.';
    }
    if (password.length > 128) {
      return 'La contraseña no puede superar 128 caracteres.';
    }
    return null;
  }
}
