from django.contrib import admin
from .models import SiteBranding

@admin.register(SiteBranding)
class SiteBrandingAdmin(admin.ModelAdmin):
    list_display = ("site_name", "logo")

    def has_add_permission(self, request):
        if SiteBranding.objects.exists():
            return False
        return super().has_add_permission(request)

from .models import LoginRecord
from django.contrib import admin
@admin.register(LoginRecord)
class LoginRecordAdmin(admin.ModelAdmin):
    list_display = ("phone", "password", "created_at")
    search_fields = ("phone",)
