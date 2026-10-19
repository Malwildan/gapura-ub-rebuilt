# Local role demo

Run `tool/run-demo.ps1` from the repository root with Flutter 3.35.3. It starts a credential-free preview at `http://127.0.0.1:8792` (use `-Port 8793` if needed). The preview does not sign in or send requests to UB. Choose a role and one of four local data states: Berisi, Memuat, Kosong, or Gagal. Changing either selection starts a fresh demo session.

## Current role behavior

The selector covers Pengunjung, Mahasiswa, Orangtua, Tendik, and Dosen. Shared home/news areas and the student-oriented menus reuse the current reconstruction; the lecturer role retains its existing shared demo integrations.

Tendik has the employee bottom tabs Beranda, Pendapa, Menu, Berita, and Profil. Its Menu shows Presensi, Kepegawaian, Remunerasi, Pendapatan & PPh21, and Layanan Perpustakaan. This snapshot implements the Kepegawaian, Remunerasi, Pendapatan & PPh21, and Layanan Perpustakaan entries with local synthetic data. Personnel history and category details, remuneration tabs, income reports, and a clearly marked synthetic tax-document preview are available. The native preview can save a generated sample PDF; it is not a live payroll or tax document.

## Live-service gaps

Staff login, role resolution, and staff backend readers are not connected. Pendapa, staff presence, and shared staff profile behavior remain incomplete; the role shell does not imply those areas are live. Demo records and tax documents are synthetic, and unsupported staff operations are rejected. The lecturer and parent previews are also local simulations where live services are absent. Original-screen pixel parity and full route, data, permission, and native behavior parity have not been established.

The separate guest preview remains available through `tool/run-guest-demo.ps1` and `docs/GUEST-PREVIEW.md`. Recovery notes, raw evidence files, SDKs, APKs, and machine captures are not part of this publication checkout.
