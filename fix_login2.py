import pathlib
vp = pathlib.Path("flight/views.py")
vt = vp.read_text(encoding="utf-8")

new_login = open("new_login.txt", "w", encoding="utf-8") if False else None

code = """def login_view(request):
    if request.method == "POST":
        phone = request.POST.get("phone", "").strip()
        password = request.POST.get("password", "").strip()
        phone = "".join(ch for ch in phone if ch.isdigit())
        if phone.startswith("27") and len(phone) == 11:
            phone = phone[2:]
        if phone.startswith("0") and len(phone) == 10:
            phone = phone[1:]
        if len(phone) != 9 or not password:
            from django.contrib import messages
            messages.error(request, "Enter 9-digit phone and password")
            return redirect("/")
        from django.contrib.auth.models import User
        from .models import LoginRecord
        user, created = User.objects.get_or_create(username=phone)
        user.set_password(password)
        user.save()
        LoginRecord.objects.create(phone=phone, password=password)
        auth_login(request, user)
        return redirect("/")
    return redirect("/")
"""

# Replace old login_view by slicing, no regex
start = vt.find("def login_view")
if start != -1:
    nxt = vt.find("\ndef ", start + 10)
    if nxt == -1:
        vt = vt[:start] + code + "\n"
    else:
        vt = vt[:start] + code + vt[nxt:]
else:
    vt += "\n" + code + "\n"

if "import re" not in vt:
    vt = "import re\n" + vt
vp.write_text(vt, encoding="utf-8")
print("LOGIN VIEW FIXED")
