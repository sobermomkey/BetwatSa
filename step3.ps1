$ErrorActionPreference = "Stop"
Set-Location "$HOME\BetWaySa"

if (-not (Test-Path "flight\templates\flight\home.html")) {
    throw "Complete Step 2 first. The flight HTML file is missing."
}

# Install image upload support
py -m pip install Pillow

# 1. Database model for editable website branding
@'
from django.db import models

class SiteBranding(models.Model):
    site_name = models.CharField(
        max_length=100,
        default="FLIGHT ZA"
    )
    logo = models.ImageField(
        upload_to="site_logos/",
        blank=True,
        null=True
    )

    def __str__(self):
        return self.site_name
'@ | Set-Content "flight\models.py" -Encoding UTF8

# 2. Enable branding management in Django Admin
@'
from django.contrib import admin
from .models import SiteBranding

@admin.register(SiteBranding)
class SiteBrandingAdmin(admin.ModelAdmin):
    list_display = ("site_name", "logo")

    def has_add_permission(self, request):
        if SiteBranding.objects.exists():
            return False
        return super().has_add_permission(request)
'@ | Set-Content "flight\admin.py" -Encoding UTF8

# 3. Configure media uploads
$settingsPath = "config\settings.py"
$settings = Get-Content $settingsPath -Raw

if ($settings -notmatch '(?m)^MEDIA_URL\s*=') {
    Add-Content $settingsPath @'

MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"
'@
}

# 4. Django routes
@'
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path("admin/", admin.site.urls),
    path("", include("flight.urls")),
]

if settings.DEBUG:
    urlpatterns += static(
        settings.MEDIA_URL,
        document_root=settings.MEDIA_ROOT
    )
'@ | Set-Content "config\urls.py" -Encoding UTF8

@'
from django.urls import path
from . import views

urlpatterns = [
    path("", views.home, name="home"),
    path("login/", views.login_view, name="login"),
    path("register/", views.register_view, name="register"),
    path("logout/", views.logout_view, name="logout"),
]
'@ | Set-Content "flight\urls.py" -Encoding UTF8

# 5. Working Django authentication
@'
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
    phone = normalize_phone(request.POST.get("phone"))
    password = request.POST.get("password", "")

    user = authenticate(
        request,
        username=phone,
        password=password
    ) if phone else None

    if user is None:
        messages.error(
            request,
            "Invalid phone number or password."
        )
        return redirect("/?modal=login")

    login(request, user)
    messages.success(request, "Login successful.")
    return redirect("home")

@require_POST
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
'@ | Set-Content "flight\views.py" -Encoding UTF8

# 6. Replace header with admin-controlled branding
$htmlPath = "flight\templates\flight\home.html"
$html = Get-Content $htmlPath -Raw

$header = @'
<header class="topbar">
  <div class="brand">
    {% if branding and branding.logo %}
      <img class="site-logo"
           src="{{ branding.logo.url }}"
           alt="Website logo">
    {% else %}
      <span class="logo-slot">LOGO</span>
    {% endif %}
    <strong>{{ branding.site_name|default:"FLIGHT ZA" }}</strong>
  </div>

  <div class="header-right">
    {% if request.user.is_authenticated %}
      <form method="post" action="{% url 'logout' %}">
        {% csrf_token %}
        <button class="login-btn">LOGOUT</button>
      </form>
    {% else %}
      <button type="button" id="loginBtn"
              class="login-btn">LOGIN</button>
    {% endif %}
    <span class="menu-icon">&#9776;</span>
  </div>
</header>
'@

$html = [regex]::Replace(
    $html,
    '(?s)<header class="topbar">.*?</header>',
    $header
)

# Add login and registration popup
$modal = @'
{% if messages %}
<div class="flash-list">
{% for message in messages %}
  <div class="flash">{{ message }}</div>
{% endfor %}
</div>
{% endif %}

<div id="authOverlay" class="auth-overlay" hidden>
  <section class="auth-card" role="dialog"
           aria-modal="true" aria-label="Account login">

    <div class="auth-header">
      <div class="auth-brand">
        {% if branding and branding.logo %}
          <img src="{{ branding.logo.url }}"
               alt="Website logo" class="site-logo">
        {% endif %}
        <strong>{{ branding.site_name|default:"FLIGHT ZA" }}</strong>
      </div>
      <button type="button" id="closeAuth"
              class="close-auth" aria-label="Close">Ã—</button>
    </div>

    <div class="auth-line"></div>

    <div id="loginPanel">
      <h2>LOGIN</h2>

      <form method="post" action="{% url 'login' %}">
        {% csrf_token %}

        <label>MOBILE NUMBER</label>
        <div class="auth-input phone-input">
          <span>+27</span>
          <input name="phone" type="tel"
                 inputmode="numeric" maxlength="9"
                 pattern="[0-9]{9}"
                 placeholder="Phone number"
                 autocomplete="tel-national" required>
        </div>

        <label>PASSWORD</label>
        <div class="auth-input">
          <input name="password" type="password"
                 placeholder="Password"
                 autocomplete="current-password"
                 required>
          <button type="button" class="toggle-password">
            Show
          </button>
        </div>

        <button type="button" id="forgotBtn"
                class="forgot-btn">
          Forgot Password?
        </button>

        <p id="forgotInfo" class="support-info" hidden>
          Contact your account administrator for
          identity verification and a secure password reset.
        </p>

        <button type="submit" class="auth-submit">
          LOGIN
        </button>
      </form>

      <div class="auth-footer">
        Don't have an account?
        <button type="button" id="showSignup">
          Sign Up
        </button>
      </div>
    </div>

    <div id="signupPanel" hidden>
      <h2>SIGN UP</h2>

      <form method="post" action="{% url 'register' %}">
        {% csrf_token %}

        <label>MOBILE NUMBER</label>
        <div class="auth-input phone-input">
          <span>+27</span>
          <input name="phone" type="tel"
                 inputmode="numeric" maxlength="9"
                 pattern="[0-9]{9}"
                 placeholder="Phone number"
                 autocomplete="tel-national" required>
        </div>

        <label>PASSWORD</label>
        <div class="auth-input">
          <input name="password" type="password"
                 placeholder="Create password"
                 autocomplete="new-password"
                 minlength="8" required>
          <button type="button" class="toggle-password">
            Show
          </button>
        </div>

        <label>CONFIRM PASSWORD</label>
        <div class="auth-input">
          <input name="confirm_password" type="password"
                 placeholder="Confirm password"
                 autocomplete="new-password"
                 required>
          <button type="button" class="toggle-password">
            Show
          </button>
        </div>

        <button type="submit" class="auth-submit">
          CREATE ACCOUNT
        </button>
      </form>

      <div class="auth-footer">
        Already registered?
        <button type="button" id="showLogin">
          Login
        </button>
      </div>
    </div>
  </section>
</div>

<script src="{% static 'flight/account.js' %}" defer></script>
'@

if ($html -notmatch 'id="authOverlay"') {
    $html = $html.Replace("</body>", "$modal`r`n</body>")
}

Set-Content $htmlPath $html -Encoding UTF8

# 7. Login modal JavaScript
@'
document.addEventListener("DOMContentLoaded", () => {
    const overlay = document.getElementById("authOverlay");
    const loginPanel = document.getElementById("loginPanel");
    const signupPanel = document.getElementById("signupPanel");

    function openAuth(panel = "login") {
        overlay.hidden = false;
        loginPanel.hidden = panel !== "login";
        signupPanel.hidden = panel !== "signup";
    }

    function closeAuth() {
        overlay.hidden = true;
    }

    document.getElementById("loginBtn")
        ?.addEventListener("click", () => openAuth());

    document.getElementById("closeAuth")
        .addEventListener("click", closeAuth);

    document.getElementById("showSignup")
        .addEventListener("click", () => openAuth("signup"));

    document.getElementById("showLogin")
        .addEventListener("click", () => openAuth("login"));

    document.getElementById("forgotBtn")
        .addEventListener("click", () => {
            const info = document.getElementById("forgotInfo");
            info.hidden = !info.hidden;
        });

    overlay.addEventListener("click", event => {
        if (event.target === overlay) closeAuth();
    });

    document.addEventListener("keydown", event => {
        if (event.key === "Escape") closeAuth();
    });

    document.querySelectorAll(".toggle-password")
        .forEach(button => {
            button.addEventListener("click", () => {
                const input = button.parentElement.querySelector("input");
                const visible = input.type === "text";
                input.type = visible ? "password" : "text";
                button.textContent = visible ? "Show" : "Hide";
            });
        });

    const panel = new URLSearchParams(location.search).get("modal");

    if (panel === "login" || panel === "signup") {
        openAuth(panel);
    }
});
'@ | Set-Content "flight\static\flight\account.js" -Encoding UTF8

# Remove the old placeholder login alert
$gamePath = "flight\static\flight\game.js"
$gameJs = Get-Content $gamePath -Raw
if ($null -eq $gameJs) { $gameJs = "" }
$gameJs = $gameJs.Replace(
    'alert("Account login will be added in Step 3.");',
    ''
)
Set-Content $gamePath $gameJs -Encoding UTF8

# 8. Dark login popup CSS
@'
.site-logo {
    max-width: 125px;
    max-height: 42px;
    object-fit: contain;
}

.auth-overlay[hidden],
#signupPanel[hidden],
#loginPanel[hidden],
#forgotInfo[hidden] {
    display: none !important;
}

.auth-overlay {
    position: fixed;
    inset: 0;
    z-index: 1000;
    background: rgba(0,0,0,.8);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 10px;
}

.auth-card {
    background: #1c1c1c;
    color: white;
    width: min(500px, 100%);
    max-height: 95vh;
    overflow-y: auto;
    border: 1px solid #333;
    border-radius: 22px;
    padding: 24px;
}

.auth-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.auth-brand {
    display: flex;
    align-items: center;
    gap: 12px;
    font-size: 24px;
}

.close-auth {
    color: #98a2b3;
    border: none;
    background: transparent;
    font-size: 28px;
}

.auth-line {
    height: 2px;
    background: #00c647;
    margin: 23px 0 26px;
}

.auth-card h2 {
    margin: 0 0 30px;
    font-size: 24px;
}

.auth-card label {
    display: block;
    color: #9ba5b5;
    font-size: 13px;
    font-weight: bold;
    margin: 18px 0 5px;
    letter-spacing: .5px;
}

.auth-input {
    display: flex;
    align-items: center;
    background: #252525;
    border: 1px solid #3c3c3c;
    border-radius: 11px;
    overflow: hidden;
    height: 49px;
}

.auth-input span {
    color: #a3adbe;
    font-size: 16px;
    padding: 14px;
    border-right: 1px solid #3c3c3c;
}

.auth-input input {
    width: 100%;
    min-width: 0;
    flex: 1;
    background: transparent;
    color: white;
    border: 0;
    outline: 0;
    font-size: 16px;
    padding: 12px 14px;
}

.toggle-password {
    background: transparent;
    border: 0;
    color: #98a2b3;
    font-weight: bold;
    padding: 12px;
}

.forgot-btn {
    display: block;
    margin: 18px 0 24px auto;
    background: none;
    border: none;
    color: #00df57;
    font-size: 14px;
    font-weight: bold;
}

.support-info {
    color: #d0d0d0;
    font-size: 13px;
    line-height: 1.6;
}

.auth-submit {
    display: block;
    width: 100%;
    height: 57px;
    border: none;
    border-radius: 12px;
    background: #117a30;
    color: white;
    font-size: 18px;
    font-weight: bold;
}

.auth-footer {
    margin-top: 25px;
    padding-top: 22px;
    border-top: 1px solid #333;
    text-align: center;
    color: #9da7b7;
    font-size: 15px;
}

.auth-footer button {
    border: 0;
    background: none;
    color: #00df57;
    font-size: 15px;
    font-weight: bold;
}

.flash-list {
    max-width: 900px;
    margin: 10px auto;
    padding: 0 15px;
}

.flash {
    background: #28352c;
    border: 1px solid #427348;
    padding: 12px;
    border-radius: 8px;
    margin-bottom: 7px;
}
'@ | Add-Content "flight\static\flight\style.css" -Encoding UTF8

# 9. Run database changes
py manage.py makemigrations flight
py manage.py migrate
py manage.py check

Write-Host "LOGIN AND LOGO ADMIN READY" -ForegroundColor Green
