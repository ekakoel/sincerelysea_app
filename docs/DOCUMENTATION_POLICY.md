# Documentation Policy

Dokumen ini menjadi aturan kerja untuk perubahan kode di proyek `SincerelySea`.

## Aturan Wajib

1. Setiap perubahan kode harus disertai pembaruan dokumentasi `.md`.
2. Perubahan yang wajib didokumentasikan:
   - penambahan file atau fitur
   - perubahan perilaku existing
   - penghapusan fitur, file, atau alur
   - perubahan aturan Firebase, struktur data, atau storage path
3. Dokumentasi minimum yang wajib diperbarui:
   - [docs/CHANGELOG.md](/Users/abc/SincerelySea/sincerelysea/docs/CHANGELOG.md)
4. Jika perubahan cukup besar atau mengubah flow produk, tambahkan juga penjelasan ringkas di `README.md` atau dokumen khusus di folder `docs/`.

## Format Changelog

Gunakan struktur tanggal:

```md
## YYYY-MM-DD

### Added
- ...

### Changed
- ...

### Removed
- ...

### Fixed
- ...
```

Hanya gunakan section yang relevan. Jangan tambahkan section kosong.

## Cakupan Dokumentasi

Dokumentasi perubahan harus menjelaskan:
- apa yang berubah
- area/file utama yang terdampak
- dampak ke flow aplikasi atau data
- catatan migrasi jika ada

## Tujuan

Aturan ini dibuat agar histori perubahan tetap jelas, audit teknis lebih mudah, dan semua penambahan/penghapusan fitur dapat dilacak tanpa membaca seluruh diff kode.
