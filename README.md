# MITM-DomainFronting

<div dir="rtl">

اول اینکه این متد قرار نیست کانفیگ شما را زنده کند و دسترسی کامل به اینترنت را
فراهم کند بلکه باعث میشود برخی سرویسهای خاص به طور مستقیم (بدون نیاز به سرور و
یا حتی ورکر) در دسترس قرار گیرند

در حال حاضر (۱۴۰۵/۳/۱۰) اجرای این متد امکان دسترسی به یوتویوب، اینستاگرام،
واتس‌آپ، فیسبوک، رددیت و بعضی سایتهای پشت فستلی را فراهم میکند.

به محض اینکه هر سرویس دیگری با این متد در دسترس باشد اپدیت لازم را انجام خواهم
داد.

این متد بر روی ویندوز، لینوکس، مک و اندروید (بدون نیاز به روت) قابل اجراست.

///

این پروژه را ابتدا من در [اینجا](https://github.com/patterniha/MMDF) نوشتم و سپس
با تلاشهای انجام شده در [اینجا](https://github.com/XTLS/Xray-core/issues/4348) به
Xray-core اضافه کردیم و یعنی اکنون میتوانید با یک کانفیگ ساده‌ی v2ray از این متد
استفاده کنید.

نحوه کارکرد متد همانطور که از اسمش پیداست ابتدا هویت سرور اصلی را جعل میکند تا
دیتای غیر رمز شده را از مرورگر دریافت کند سپس با یک sni جعلی آن را به سرور اصلی
میفرستد.

تنظیم اولیه متد مراحل کمی طولانی دارد ولی بعد از انجام تنظیمات صرفا یک روشن/خاموش
ساده برای فعال/غیرفعال کردن متد لازم است.

## راه اندازی در ویندوز

۱. ابتدا آخرین ورژن برنامه v2rayN (v2rayN-windows-64.zip ) را از
https://github.com/2dust/v2rayN/releases دانلود و اکسترکت کنید

۲. حال نیاز به یک سرتیفیکیت شخصی دارید برای این کار فایل
certificate_generator.bat را به فولدر v2rayN-windows-64\bin منتقل و در همانجا
اجرا کنید کمی صبر کنید سپس دو فایل mycert.crt و mycert.key ایجاد میشود

**هشدار: حتما از سرتیفیکیت شخصی خود استفاده کنید و به هیچ عنوان از سرتیفیکیت
(crt) دیگران استفاده نکنید و همچنین فایل پرایویت‌کی (key) خود را به هیچ شخصی
ندهید**

۳. حال باید سرتیفیکیت (crt) ایجاد شده را به عنوان trusted root certificate به
سیستم عامل (برای تایید روی کل سیستم) و یا یک مرورگر خاص خود معرفی کنید

برای معرفی به سیستم عامل باید روی mycert.crt راست کلیک کنید و install
certificate را انتخاب کنید سپس گزینه local machine را انتخاب کنید در صفحه بعد
place all certificates in the following store را انتخاب و

فولدر Trusted Root Certification Authorities را انتخاب کنید و تایید کنید

برای مرورگر نیز به طور مثال کروم باید مراحل زیر را طی کنید

Settings -> Privacy and security -> Security -> Manage certificates -> Manage
imported certificates from Windows -> Trusted Root Certification Authorities ->
Import -> Select mycert.crt file -> Place all certificates in the following
store -> Select "Trusted Root Certification Authorities"

۴. نرم افزار v2rayN را اجرا کنید و از قسمت configuration بر روی add a custom
configuration کلیک کنید حال یک نام دلخواه انتخاب کنید و فایل کانفیگ
MITM-DomainFronting.json را وارد کنید core type را بر روی xray و socks port را
حتما خالی بزارید

۵. کانفیگ را انتخاب کرده و set system proxy را انتخاب کنید کار تمام است اکنون
میتوانید بر روی مرورگری که سرتیفیکیت را در آن وارد کردید (و یا کل سیستم در صورتی
که سرتیفیکیت را به سیستم عامل معرفی کردید) از این متد استفاده کنید.

## راه اندازی در اندروید

۱. ابتدا آخرین ورژن برنامه v2rayNG را از
https://github.com/2dust/v2rayNG/releases دانلود و نصب کنید

۲. حال نیاز به یک سرتیفیکیت شخصی دارید برای اینکار میتوانید همان فایلهای
mycert.crt, mycert.key را که در ویندوز ایجاد کردید را به گوشی خود منتقل کنید و
از همانها استفاده کنید یا اینکه به طور مثال میتوانید به طور مستقیم از سایت

https://regery.com/en/security/ssl-tools/self-signed-certificate-generator

با یک نام دلخواه سرتیفیکیت بسازید و هر دو فایل crt و key را دانلود کنید در این
صورت باید نام فایل crt را به mycert.crt و نام فایل key را به mycert.key تغییر
دهید

**هشدار: حتما از سرتیفیکیت شخصی خود استفاده کنید و به هیچ عنوان از سرتیفیکیت
(crt) دیگران استفاده نکنید و همچنین فایل پرایویت‌کی (key) خود را به هیچ شخصی
ندهید**

۳. در برنامه v2rayNG و در قسمت Asset files هر دو فایل mycert.crt, mycert.key را
وارد کنید

۴. حال باید سرتیفیکیت (crt) را به عنوان یک trusted root certificate به سیستم
عامل اندروید معرفی کنید برای این کار مراحل زیر را طی کنید:

Setting -> Security and privacy -> More security settings -> Install from device
storage -> CA Certificate -> Install anyway -> Select mycert.crt file on your
storage.

اگر با موفقیت این قسمت انجام شود میتوانید سرتیفیکیت وارد شده را در قسمت

Setting -> Security and privacy -> More security settings -> View security
certificates -> User.

مشاهده کنید، دقت کنید که این مراحل ممکن است بر روی گوشی های مختلف کمی متفاوت
باشد

۵. کانفیگ MITM-DomainFronting.json را از طریق import from locally وارد
برنامهv2rayNG کنید و اجرا کنید همچنین دقت کنید که Enable Hev TUN FEATURE در
تنظیمات v2rayNG فعال باشد و همچنین پورت پیشفرض 10808 را تغییر نداده باشید.

۶. کار تمام است اکنون میتوانید بر روی مرورگر کروم (و به طور کلی تمامی مرورگرهای
مبتنی بر کرومیوم) از این متد استفاده کنید

و در صورتی که از مرورگر فایرفاکس استفاده میکنید باید مراحل اضافه زیر را طی کنید

firefox browser -> Settings -> About Firefox -> Tap the Firefox logo five times
-> Navigate to Settings -> Secret Settings -> Toggle "Use third party CA
certificates"

دقت کنید برای اندروید غیر روت فقط از طریق مرورگرها میتوانید ازین متد استفاده
کنید و برنامه های مستقل امکان استفاده از این متد را معمولا ندارند.

## راه اندازی در لینوکس

۱. ابتدا اسکریپت تنظیم را اجرا کنید:

```bash
chmod +x Xray-config/linux-key-generator.sh && ./Xray-config/linux-key-generator.sh
```

گزینه ۳ (Do both) را انتخاب کنید تا هم سرتیفیکیت ایجاد شود و هم Xray دانلود شود.

۲. حال باید سرتیفیکیت ایجاد شده (`Xray-config/mycert.crt`) را به عنوان trusted
root certificate به سیستم عامل معرفی کنید:

**برای اوبونتو/دبیان:**

```bash
sudo cp Xray-config/mycert.crt /usr/local/share/ca-certificates/mycert.crt
sudo update-ca-certificates
```

**برای فدورا/ردهت:**

```bash
sudo cp Xray-config/mycert.crt /etc/pki/ca-trust/source/anchors/mycert.crt
sudo update-ca-trust
```

۳. اگر از فایرفاکس استفاده میکنید باید سرتیفیکیت را به مرورگر نیز معرفی کنید:

Firefox Settings -> Privacy & Security -> Certificates -> View Certificates ->
تب Authorities -> Import -> فایل `Xray-config/mycert.crt` را انتخاب کنید ->
گزینه Trust to identify websites را فعال کنید

۴. Xray را با کانفیگ MITM Domain Fronting اجرا کنید:

```bash
chmod +x ./Xray/xray && ./Xray/xray run -c ./Xray-config/MITM-DomainFronting.json
```

۵. مرورگر خود را برای استفاده از پروکسی تنظیم کنید:

- آدرس پروکسی: 127.0.0.1
- پورت: 10808
- نوع: SOCKS5

۶. کار تمام است! اکنون میتوانید در مرورگر فایرفاکس از این متد استفاده کنید (برای
کروم بهتر است از اکستنشن proxy switcher استفاده کنید).

**نکته:** در لینوکس نیز مانند اندروید، فقط از طریق مرورگرها میتوانید از این متد
استفاده کنید و برنامه های مستقل معمولا پشتیبانی نمیکنند.

# هشدار ها و نکات

۱. **باز هم تاکید میکنم فایل سرتیفیکیت (crt) را از کسی نگیرید و فایل پرایویت‌کی
(key) را به هیچ شخصی ندهید به طور ساده این دو فایل را نه به کسی بدهید و نه از
کسی بگیرید و خودتان به صورت شخصی ایجاد و از آن استفاده کنید**

۲. برای اندروید غیر روت ازین متد فقط میتوانید بر روی مرورگرها استفاده کنید و اپ
های مستقل معمولا از این متد پشتیبانی نمیکنند

بنابراین برای استفاده از google meet و یا google drive و ... باید از مرورگر
استفاده کنید.

۳. زحمت زیادی برای برای این برنامه کشیده شده از نوشتن کد پایتون اولیه تا اضافه
کردن آن به هسته xray امیدوارم حمایت از بنده فراموش نشه همچنان کارهای بزرگی در
پیش هست ...

</div>

USDT (BEP20): 0x76a768B53Ca77B43086946315f0BDF21156bF424

USDT (TRC20): TU5gKvKqcXPn8itp1DouBCwcqGHMemBm8o

@patterniha
