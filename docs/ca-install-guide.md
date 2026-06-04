# راهنمای نصب گواهی (CA)

## هدف

نصب فایل گواهی تولید شده محلی (`mycert.crt`) تا مرورگر یا سیستم‌عامل شما به گواهی‌های صادر شده توسط تونل محلی Xray اعتماد کند. مراحل پلتفرم خود را در زیر دنبال کنید، اثر انگشت (SHA-256 fingerprint) را قبل از نصب ثبت کنید و قبل از عیب‌یابی مسیرها یا DNS، فرآیند تأیید را کامل کنید.

## ویندوز: نصب برای کاربر فعلی یا کل سیستم (Local Machine)

برای بیشتر کاربران توصیه می‌شود: گواهی را فقط در جایی که نیاز است نصب کنید. در صورت امکان، اعتماد در سطح مرورگر خاص ترجیح داده می‌شود.

مراحل اصلی در ویندوز:

1. روی فایل `mycert.crt` دو بار کلیک کنید.
2. گزینه **Install Certificate** را انتخاب کنید.
3. گزینه **Current User** (کاربر فعلی) یا **Local Machine** (کل سیستم) را انتخاب کنید.
4. گزینه **Place all certificates in the following store** را انتخاب کنید.
5. پوشه **Trusted Root Certification Authorities** (مراجع صدور گواهی ریشه قابل اعتماد) را انتخاب کنید.
6. مراحل ویزارد را به پایان برسانید.
7. اثر انگشت را با استفاده از راهنمای [`ca-verify-guide.md`](ca-verify-guide.md) تأیید کنید.

قبل از نصب، دستور زیر را اجرا کنید تا اثر انگشت را ببینید:

```bash
python scripts/mitm_trust.py status --cert Xray-config/mycert.crt --key Xray-config/mycert.key
```

اثر انگشت SHA-256 نشان داده شده را یادداشت کنید. پس از نصب، مطمئن شوید اثر انگشت گواهی نصب‌شده با این مقدار مطابقت دارد.

بررسی اثر انگشت با PowerShell:

```powershell
Get-FileHash .\Xray-config\mycert.crt -Algorithm SHA256
```

## مک (macOS)

1. برنامه **Keychain Access** را باز کنید.
2. فایل `mycert.crt` را به بخش login keychain یا System keychain بکشید و رها کنید (Drag and Drop).
3. روی گواهی دوبار کلیک کنید تا باز شود.
4. بخش **Trust** را باز کنید.
5. تنظیمات SSL trust را روی "Always Trust" یا متناسب با نیاز خود قرار دهید.
6. اثر انگشت گواهی را تأیید کنید.

## لینوکس (Linux)

مسیرهای ذخیره گواهی‌های معتبر در توزیع‌های مختلف لینوکس متفاوت است. روش‌های رایج:

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

مرورگر فایرفاکس (Firefox) ممکن است بسته به تنظیماتش نیاز داشته باشد که گواهی را مستقیماً در بخش تنظیمات خود مرورگر وارد کنید.

## اندروید (Android)

1. فایل `mycert.crt` را به دستگاه خود منتقل کنید.
2. تنظیمات اندروید (Settings) را باز کنید.
3. به بخش امنیت / رمزنگاری / ذخیره‌ساز اعتبار (Security / Encryption / Credential Storage) بروید.
4. گزینه **Install from device storage** (نصب از حافظه دستگاه) را انتخاب کنید.
5. گزینه **CA certificate** را انتخاب کنید.
6. فایل `mycert.crt` را انتخاب کرده و تأیید کنید.
7. مطمئن شوید که گواهی در بخش User certificates ظاهر شده است.

برخی برنامه‌های اندرویدی ممکن است گواهی‌های کاربر را نادیده بگیرند یا از پین کردن گواهی (Certificate Pinning) استفاده کنند. موفقیت در مرورگر تضمینی برای کارکرد در تمام برنامه‌ها نیست.

## تأیید الزامی است

پس از نصب، همیشه مراحل راهنمای تأیید را اجرا کنید. قبل از اطمینان از صحت اثر انگشت گواهی ریشه نصب‌شده، اقدام به عیب‌یابی مسیرها نکنید.

## مستندات مرتبط

| مستند | موضوع |
|---|---|
| [`ca-verify-guide.md`](ca-verify-guide.md) | بررسی اثر انگشت و مخزن گواهی‌ها |
| [`ca-rotate-guide.md`](ca-rotate-guide.md) | جایگزینی گواهی‌های منقضی شده یا نامعتبر |
| [`certificate-lifecycle.md`](certificate-lifecycle.md) | وضعیت‌ها و چرخه‌های عمر گواهی ریشه |
| [`android-guide.md`](android-guide.md) | راه‌اندازی v2rayNG و گواهی کاربر در اندروید |
