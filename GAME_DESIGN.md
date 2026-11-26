# Kart Nusantara - Chaos Racing

- **Genre:** 3D Arcade Racing, Action, Comedy
- **Visual:** Stylized 3D, semi-realistis, tekstur detail (PBR Albedo + Normal Map), penuh warna, dengan pencahayaan natural tropis.
- **Target Performa:** 60 FPS stabil pada PC kelas menengah (termasuk iGPU seperti AMD Radeon 680M, VRAM 2 GB).
- **Platform:** Windows (`x86_64`) dan Linux (`x86_64`), dengan **Android** (`APK/AAB`, landscape + kontrol sentuh siap pakai) sebagai pengembangan berikutnya.
- **Stack:** Blender 5.2 (aset `.glb` + tekstur PBR) & Godot 4.7.2 (renderer `GL Compatibility` — lintas platform Windows/Linux/Android dan optimal di AMD Radeon 680M).

## Daftar 12 Fitur Utama
1. **Chaos Racing**: Balapan 8 gokart dalam satu lintasan (1 Pemain + 7 AI).
2. **AI Opponents**: 7 karakter lawan dengan profil kecepatan, drift, shortcut, dan agresivitas berbeda.
3. **Drift System**: Drifting menghasilkan energi turbo bertahap dengan percikan visual.
4. **Nitro Boost**: Akselerasi tambahan dari energi turbo dengan efek visual api knalpot & FOV boost.
5. **Destructible Objects**: Kardus, pagar kayu, gerobak, dan tong dapat ditabrak hingga terpental/hancur.
6. **Power-up**: Kulit pisang, roket kartun, bom air, oli, dan perisai.
7. **Collision Physics**: Gokart dapat terpental, berputar (spin-out), dan terguling (roll/flip) saat tabrakan keras atau kena hazard.
8. **Shortcut**: Jalur rahasia menembus gang warung/ramp untuk mendahului lawan.
9. **Dynamic Obstacles**: Ayam menyeberang, angkot bergerak/ngetem, penghalang bergerak, dan objek dinamis di lintasan.
10. **Garage**: Pemilihan model/preset gokart (Bajaj Turbo, Vespa Modif, Gerobak Roket) serta modifikasi warna bodi, spoiler, ukuran ban, dan tuning mesin.
11. **Battle Arena**: Mode arena saling menghancurkan kendaraan dengan HP, item ofensif, tabrakan keras, dan skor eliminasi.
12. **Replay Camera**: Rekaman lintasan otomatis dan kamera sinematik multi-sudut (chase, orbit, trackside) setelah balapan/pertandingan selesai.

## Kontrol
- `W / S` atau Panah Atas/Bawah: Gas / Rem & Mundur
- `A / D` atau Panah Kiri/Kanan: Belok
- `Space` atau `Shift`: Drift (isi energi Nitro) + Hop
- `Q`: Aktifkan Nitro Boost
- `E` atau `Enter`: Gunakan Power-up
- `H`: Klakson Telolet (Comedy Horn!)
- `R`: Reset posisi kart ke lintasan
- `Esc`: Kembali ke Garage / Menu Utama
