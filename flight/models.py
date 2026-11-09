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
