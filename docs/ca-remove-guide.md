# راهنمای حذف گواهی (CA)

## هدف

پاک‌سازی و حذف گواهی ریشه تستی محلی از سیستم‌عامل و مرورگرها و حذف فایل‌های گواهی پس از اتمام استفاده از متد. تمامی مراحل را طی کنید تا باقی ماندن گواهی‌های قدیمی باعث خطای امنیتی یا رفتارهای غیرمنتظره در مرورگر نشود.

## مرحله ۱: متوقف کردن کلاینت

برنامه v2rayN، v2rayNG، Xray یا هر کلاینت دیگری که از فایل کانفیگ استفاده می‌کند را متوقف کنید.

## مرحله ۲: غیرفعال کردن تنظیمات پروکسی / VPN

پروکسی سیستم (System Proxy) یا حالت TUN/VPN را در کلاینت خاموش کنید.

## مرحله ۳: حذف گواهی نصب‌شده از مخازن اعتماد سیستم

ویندوز:
1. بخش مدیریت گواهی‌های سیستم را باز کنید (از طریق جستجوی `Manage User Certificates` در منوی استارت).
2. به بخش Trusted Root Certification Authorities رفته و روی Certificates کلیک کنید.
3. گواهی صادر شده با نام گواهی خودتان را پیدا کنید.
4. آن را حذف (Delete) کنید.

مک (macOS):
1. برنامه **Keychain Access** را باز کنید.
2. گواهی مورد نظر را پیدا کنید.
3. آن را حذف کنید.

لینوکس (Linux):
دبیان / اوبونتو (Debian/Ubuntu):
```bash
sudo rm -f /usr/local/share/ca-certificates/mitm-domainfronting-mycert.crt
sudo update-ca-certificates --fresh
```

فدورا / رد‌هت (Fedora/RHEL):
```bash
sudo rm -f /etc/pki/ca-trust/source/anchors/mitm-domainfronting-mycert.crt
sudo update-ca-trust
```

اندروید (Android):
1. تنظیمات گوشی (Settings) را باز کنید.
2. به بخش گواهی‌های امنیتی / گواهی‌های کاربر (Security Certificates / User Credentials) بروید.
3. گواهی نصب‌شده را پیدا کرده و حذف (Remove) کنید.

## مرحله ۴: حذف فایلهای محلی

دستور زیر را در ترمینال اجرا کنید تا فایل‌های گواهی و کلید خصوصی از پوشه برنامه حذف شوند:

```bash
python scripts/mitm_trust.py remove-local --cert Xray-config/mycert.crt --key Xray-config/mycert.key --yes
```

## مستندات مرتبط

| مستند | موضوع |
|---|---|
| [`ca-verify-guide.md`](ca-verify-guide.md) | بررسی حذف صحیح و عدم تطابق اثر انگشت |
| [`certificate-lifecycle.md`](certificate-lifecycle.md) | چرخه عمر فایل‌ها و مدیریت گواهی ریشه |
