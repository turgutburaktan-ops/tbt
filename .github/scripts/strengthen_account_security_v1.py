from pathlib import Path
import subprocess

p = Path('lib/screens/account_security_gate.dart')
s = p.read_text()
if s.strip() == 'PLACEHOLDER':
    commits = subprocess.check_output(['git', 'rev-list', 'HEAD'], text=True).splitlines()
    for commit in commits[1:]:
        try:
            candidate = subprocess.check_output(
                ['git', 'show', f'{commit}:lib/screens/account_security_gate.dart'],
                text=True,
                stderr=subprocess.DEVNULL,
            )
        except subprocess.CalledProcessError:
            continue
        if candidate.strip() and candidate.strip() != 'PLACEHOLDER':
            s = candidate
            break

block = """    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null && !user.emailVerified) {
      return const EmailSecuritySetupScreen();
    }

"""
while s.count(block) > 1:
    pos = s.rfind(block)
    s = s[:pos] + s[pos + len(block):]

phone_gate = """    if (!_phoneVerified) {
      return const PhoneSecuritySetupScreen();
    }
"""
if block not in s and phone_gate in s:
    s = s.replace(phone_gate, block + phone_gate, 1)
p.write_text(s)

p = Path('lib/screens/register_screen.dart')
s = p.read_text()
needle = """      await AuthService.instance.register(email: email, password: password);
      accountCreated = true;
      await AuthService.instance.updateDisplayName(username);
"""
replacement = needle + "      await FirebaseAuth.instance.currentUser?.sendEmailVerification();\n"
if needle in s and 'sendEmailVerification();' not in s:
    s = s.replace(needle, replacement, 1)
p.write_text(s)
