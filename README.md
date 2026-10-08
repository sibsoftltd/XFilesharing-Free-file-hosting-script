# XFileSharing Free — free file hosting script (Perl)

XFileSharing Free is the free, open-source edition of **[XFileSharing Pro](https://sibsoft.net/xfilesharing.html)**, a self-hosted file hosting and file sharing script by [SibSoft](https://sibsoft.net/), developed since 2006 and used by 500+ file hosting sites.

Use it to learn how a file upload site works, or as a starting point for a small private upload service.

> **Note:** this is the classic 1.x code base (last release 1.21, 2011). It is kept here for reference and is not maintained. For a public file hosting site, use [XFileSharing Pro](https://sibsoft.net/xfilesharing.html), which gets regular security and feature updates (current version 4.3, July 2026).

## Features (Free)

- AJAX upload progress bar, multiple file upload, unlimited file size
- Upload limits per file and in total, allowed and blocked extensions
- Unique download links, password-protected downloads, link expiry time
- Captcha on downloads, IP and network allow/deny lists
- Download countdown page (room for your ads)
- Email notifications to the uploader and to the admin
- Admin area with upload and download statistics and settings
- ClamAV antivirus check (if ClamAV is installed)
- Plain HTML templates, easy to rebrand

## Free vs Pro

| | Free | [Pro](https://sibsoft.net/xfilesharing.html) |
|---|---|---|
| Price | Free, MIT license | $150 one-time, full source code |
| Updates and security fixes | No (2011 code base) | Yes, current version 4.3 |
| Multiple file servers, in any country | No | Yes, unlimited |
| User accounts and premium memberships | No | Yes |
| Affiliate system (webmaster and reseller via mods) | No | Yes |
| Remote URL, FTP and torrent upload | No | Yes |
| Download and upload speed control | No | Yes |
| Drag-and-drop and desktop uploader (pause/resume) | No | Yes |
| Duplicate file detection | No | Yes |
| Multi-language interface | No | Yes |
| Support | None | Tickets, knowledge base, forum |

**[See XFileSharing Pro](https://sibsoft.net/xfilesharing.html)** · [Live demo](https://sibsoft.net/xfilesharing/demo.html) · [Features](https://sibsoft.net/xfilesharing/features.html) · [Mods](https://sibsoft.net/xfilesharing/mods.html)

## Requirements

- Perl 5.005 or newer
- MySQL or MariaDB
- Apache with `mod_rewrite` and `.htaccess` support
- GD library and GD Perl module (optional)

## Installation

See [INSTALL.txt](INSTALL.txt). In short:

1. Copy `cgi-bin/` into your CGI folder and `public_html/` into your document root.
2. Set `install.cgi` to 755 and open it in a browser.
3. Delete `install.cgi` and `install.sql` after installation.
4. Edit `XFileConfig.pm` with your site details and admin password.

## License

Released under the [MIT license](http://opensource.org/licenses/MIT). You may use and modify it freely; the SibSoft copyright must stay in place on every installation. XFileSharing is a trademark of [SibSoft Ltd](https://sibsoft.net/).

This free edition comes as is, without support. Questions about XFileSharing Pro: [knowledge base](https://sibsoft.net/kb/), [community forum](https://sibsoft.net/forum/), [support portal](https://support.sibsoft.net/).
