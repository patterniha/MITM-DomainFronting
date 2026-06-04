# راهنمای لینوکس

## هدف

تولید گواهی ریشه (CA) محلی، نصب و معتبرسازی آن در مخزن توزیع‌های مختلف لینوکس، اجرای هسته Xray با فایل پیکربندی اصلی و تأیید باز بودن پورت‌های محلی با دستوراتی مانند `ss`.

## مراحل راه‌اندازی

1. مطمئن شوید هسته Xray در سیستم نصب شده یا در پوشه جاری در دسترس است.
2. گواهی ریشه محلی را با دستور زیر تولید کنید:

```bash
sh Xray-config/certificate_generator.sh Xray-config
```

3. فایل `mycert.crt` را در مخزن گواهی‌های معتبر توزیع لینوکس خود نصب کنید (در بخش زیر آمده است).
4. فایل کانفیگ `MITM-DomainFronting.json` را در کلاینت خود ایمپورت کرده یا Xray را مستقیماً با آن اجرا کنید.
5. وضعیت پورت‌ها را با دستور زیر بررسی کنید:

```bash
ss -ltnp | grep -E ':10808|:11666|:11777'
```

خروجی مورد انتظار: پورت‌ها باید فقط روی آدرس لوکال‌بک (`127.0.0.1` یا `[::1]`) گوش دهند.

## دستورات نصب گواهی در توزیع‌های رایج لینوکس

دبیان / اوبونتو (Debian/Ubuntu):

```bash
sudo cp Xray-config/mycert.crt /usr/local/share/ca-certificates/mitm-domainfronting-mycert.crt
sudo update-ca-certificates
```

فدورا / رد‌هت (Fedora/RHEL):

```bash
sudo cp Xray-config/mycert.crt /etc/pki/ca-trust/source/anchors/mitm-domainfronting-mycert.crt
sudo update-ca-trust
```

## مستندات مرتبط

| مستند | موضوع |
|---|---|
| [`ca-install-guide.md`](ca-install-guide.md) | آموزش جامع نصب گواهی در لینوکس |
| [`troubleshooting.md`](troubleshooting.md) | راهنمای جامع عیب‌یابی و نشانه‌های خطا |
