# MITM-DomainFronting - Linux Setup Guide

<div dir="rtl">

## راه‌اندازی در لینوکس (فدورا، اوبونتو، دبیان، آرچ)

این راهنما برای نصب و راه‌اندازی MITM Domain Fronting در سیستم‌های لینوکس است.

### پیش‌نیازها

- دسترسی root (sudo)
- اتصال به اینترنت برای دانلود بسته‌ها
- یکی از توزیع‌های پشتیبانی شده: Fedora، RHEL، CentOS، Ubuntu، Debian، Arch

### مراحل نصب

#### ۱. نصب Xray-core

ابتدا اسکریپت نصب Xray را اجرا کنید:

```bash
sudo ./mitm_linux.sh install-xray
```

این اسکریپت به طور خودکار:
- وابستگی‌های لازم را نصب می‌کند
- آخرین نسخه Xray-core را دانلود می‌کند
- Xray را در `/usr/local/bin` نصب می‌کند
- فایل‌های geoip و geosite را کپی می‌کند

#### ۲. ایجاد سرتیفیکیت شخصی

به دایرکتوری Xray-config بروید و اسکریپت تولید سرتیفیکیت را اجرا کنید:

```bash
cd Xray-config
./certificate_generator.sh
cd ..
```

این دستور دو فایل `mycert.crt` و `mycert.key` ایجاد می‌کند.

**⚠️ هشدار مهم: فایل `mycert.key` را به هیچ کس ندهید و از سرتیفیکیت دیگران استفاده نکنید!**

#### ۳. نصب سرتیفیکیت در سیستم

برای نصب سرتیفیکیت در trust store سیستم:

```bash
sudo ./mitm_linux.sh install-cert
```

این اسکریپت به طور خودکار سرتیفیکیت را بر اساس توزیع لینوکس شما نصب می‌کند.

#### ۴. نصب سرتیفیکیت در مرورگر

##### Firefox

1. Settings → Privacy & Security → Certificates → View Certificates
2. Authorities → Import
3. فایل `mycert.crt` را انتخاب کنید
4. گزینه "Trust this CA to identify websites" را فعال کنید

##### Chrome/Chromium

1. Settings → Privacy and security → Security → Manage certificates
2. Authorities → Import
3. فایل `mycert.crt` را انتخاب کنید
4. گزینه "Trust this certificate for identifying websites" را فعال کنید

#### ۵. اجرای Xray

برای اجرای Xray از اسکریپت آماده استفاده کنید:

```bash
./mitm_linux.sh run
```

یا به صورت دستی:

```bash
cd Xray-config
xray run -c MITM-DomainFronting.json
```

#### ۶. تنظیم پروکسی

پس از اجرای Xray، باید پروکسی سیستم یا مرورگر خود را تنظیم کنید:

**آدرس پروکسی:** `127.0.0.1:10808`

##### تنظیم پروکسی سیستم در Fedora/GNOME:

```bash
# تنظیم پروکسی HTTP و HTTPS
gsettings set org.gnome.system.proxy mode 'manual'
gsettings set org.gnome.system.proxy.http host '127.0.0.1'
gsettings set org.gnome.system.proxy.http port 10808
gsettings set org.gnome.system.proxy.https host '127.0.0.1'
gsettings set org.gnome.system.proxy.https port 10808
gsettings set org.gnome.system.proxy.socks host '127.0.0.1'
gsettings set org.gnome.system.proxy.socks port 10808

# غیرفعال کردن پروکسی
gsettings set org.gnome.system.proxy mode 'none'
```

یا از طریق رابط گرافیکی:
Settings → Network → Network Proxy → Manual

##### تنظیم پروکسی در Firefox:

Settings → General → Network Settings → Manual proxy configuration
- HTTP Proxy: `127.0.0.1` Port: `10808`
- HTTPS Proxy: `127.0.0.1` Port: `10808`
- SOCKS Host: `127.0.0.1` Port: `10808`
- انتخاب SOCKS v5
- فعال کردن "Proxy DNS when using SOCKS v5"

##### تنظیم پروکسی در Chrome/Chromium:

از افزونه‌های مدیریت پروکسی مانند SwitchyOmega استفاده کنید.

### راه‌اندازی به عنوان سرویس Systemd (اختیاری)

برای اجرای خودکار Xray در هنگام بوت سیستم:

```bash
sudo ./mitm_linux.sh setup-service
```

سپس سرویس را فعال کنید:

```bash
sudo systemctl enable xray-mitm
sudo systemctl start xray-mitm
```

دستورات مفید:

```bash
# مشاهده وضعیت
sudo systemctl status xray-mitm

# توقف سرویس
sudo systemctl stop xray-mitm

# مشاهده لاگ‌ها
sudo journalctl -u xray-mitm -f
```

### عیب‌یابی

#### خطای "certificate not trusted"

- مطمئن شوید که سرتیفیکیت را در سیستم و مرورگر نصب کرده‌اید
- مرورگر را ببندید و دوباره باز کنید
- در Firefox، مطمئن شوید که گزینه "Query OCSP responder servers" غیرفعال است

#### Xray اجرا نمی‌شود

```bash
# بررسی نسخه Xray
xray version

# اجرای Xray با لاگ کامل
cd Xray-config
xray run -c MITM-DomainFronting.json -loglevel debug
```

#### پروکسی کار نمی‌کند

- مطمئن شوید Xray در حال اجراست
- بررسی کنید که پورت 10808 باز است: `ss -tlnp | grep 10808`
- فایروال را بررسی کنید: `sudo firewall-cmd --list-all` (Fedora)

#### دسترسی به برخی سایت‌ها

این متد فقط برای سرویس‌های خاصی کار می‌کند:
- YouTube
- Instagram
- WhatsApp
- Facebook
- Reddit
- برخی سایت‌های پشت Fastly CDN

برای سایت‌های دیگر نیاز به VPN یا پروکسی معمولی دارید.

### حذف نصب

برای حذف کامل:

```bash
# توقف و حذف سرویس (اگر نصب کرده‌اید)
sudo systemctl stop xray-mitm
sudo systemctl disable xray-mitm
sudo rm /etc/systemd/system/xray-mitm.service
sudo systemctl daemon-reload

# حذف Xray
sudo rm /usr/local/bin/xray
sudo rm -rf /usr/local/share/xray

# حذف سرتیفیکیت از سیستم
# Fedora/RHEL:
sudo rm /etc/pki/ca-trust/source/anchors/mycert.crt
sudo update-ca-trust

# Debian/Ubuntu:
sudo rm /usr/local/share/ca-certificates/mycert.crt
sudo update-ca-certificates

# حذف سرتیفیکیت از مرورگر را به صورت دستی انجام دهید
```

### نکات امنیتی

1. **هرگز فایل `mycert.key` را به اشتراک نگذارید**
2. **از سرتیفیکیت دیگران استفاده نکنید**
3. این متد ترافیک شما را رمزگشایی و دوباره رمزگذاری می‌کند
4. فقط برای دسترسی به سرویس‌های مسدود شده استفاده کنید
5. برای کارهای حساس از VPN معتبر استفاده کنید

### سوالات متداول

**س: آیا نیاز به VPN دارم؟**

ج: خیر، این متد بدون نیاز به سرور VPN کار می‌کند.

**س: چرا برخی سایت‌ها کار نمی‌کنند؟**

ج: این متد فقط برای سرویس‌های خاصی که در کانفیگ تعریف شده‌اند کار می‌کند.

**س: آیا می‌توانم روی چند دستگاه استفاده کنم؟**

ج: بله، می‌توانید سرتیفیکیت را روی دستگاه‌های دیگر نصب کنید و آن‌ها را به پروکسی متصل کنید.

**س: چگونه می‌توانم سرویس‌های بیشتری اضافه کنم؟**

ج: باید فایل کانفیگ JSON را ویرایش کنید و دامنه‌های جدید را اضافه کنید.

</div>

---

## Linux Setup Guide (English)

### Quick Start

1. Install Xray: `sudo ./mitm_linux.sh install-xray`
2. Generate certificate: `./mitm_linux.sh generate-cert`
3. Install certificate: `sudo ./mitm_linux.sh install-cert`
4. Install certificate in your browser (see instructions above)
5. Run Xray: `./mitm_linux.sh run`
6. Configure proxy: `127.0.0.1:10808`

### Supported Distributions

- Fedora / RHEL / CentOS / Rocky Linux / AlmaLinux
- Ubuntu / Debian / Linux Mint
- Arch Linux / Manjaro

### System Requirements

- Linux kernel 3.10+
- 50MB free disk space
- Root access (sudo)

### Scripts Overview

- `mitm_linux.sh install-xray` - Installs Xray-core
- `mitm_linux.sh generate-cert` - Generates self-signed certificate
- `mitm_linux.sh install-cert` - Installs certificate to system trust store
- `mitm_linux.sh run` - Runs Xray with MITM config
- `mitm_linux.sh setup-service` - Creates systemd service for auto-start

### Support

For issues and questions, please open an issue on GitHub.

### Credits

Created by @patterniha

Donations:
- USDT (BEP20): 0x76a768B53Ca77B43086946315f0BDF21156bF424
- USDT (TRC20): TU5gKvKqcXPn8itp1DouBCwcqGHMemBm8o
