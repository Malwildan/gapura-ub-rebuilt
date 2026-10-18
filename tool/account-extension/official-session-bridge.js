/* Optional preview pairing in the official UB dashboard. */
async function readOfficialAccount(action, parameters) {
  let attendanceLock = false, surveyLock = false;
  const surveyReload = action === 'surveyStatus' && globalThis.gapuraSurveyUnknown && !globalThis.gapuraSurveyInFlight;
  try {
    if (location.origin !== 'https://akun.ub.ac.id' || !location.pathname.startsWith('/dashboard')) throw Error('Buka dashboard resmi akun UB terlebih dahulu.');
    const invalidTerm = 'Pilihan semester tidak valid. Pilih tahun dan semester yang lengkap.';
    if (!parameters || typeof parameters !== 'object' || Array.isArray(parameters)) throw Error('Parameter akun tidak valid.');
    const hasShort = Object.prototype.hasOwnProperty.call(parameters, 'short');
    if (hasShort && typeof parameters.short !== 'boolean') throw Error(invalidTerm);
    const short = parameters.short === true;
    const hasYear = parameters.year !== undefined && parameters.year !== null;
    const hasOdd = parameters.odd !== undefined && parameters.odd !== null;
    if (hasYear !== hasOdd || (hasYear && (typeof parameters.year !== 'string' || !/^[0-9]{4}$/.test(parameters.year) || Number(parameters.year) < 1900 || Number(parameters.year) > 2200 || typeof parameters.odd !== 'boolean'))) throw Error(invalidTerm);
    const explicitPeriod = hasYear ? {tahun:parameters.year,is_ganjil:parameters.odd ? '1' : '0',is_pendek:short ? '1' : '0'} : null;
    if (action === 'schedule' && explicitPeriod) throw Error('Jadwal kuliah hanya menerima pilihan semester reguler atau pendek.');
    if (action === 'finance' && (explicitPeriod || short)) throw Error('Tagihan memakai periode layanan UB dan tidak menerima pilihan semester.');
    if (action === 'history' && (short || parameters.course?.IS_PENDEK === true || String(parameters.course?.IS_PENDEK) === '1')) throw Error('Riwayat materi semester pendek belum tersedia untuk kontrak ini.');
    const readActions = ['connection','identity','profile','schedule','krs','grades','transcript','finance','announcements','materials','history','surveyStatus','surveyQuestions','attendanceMeetings'];
    if (!readActions.includes(action) && action !== 'attendanceSubmit' && action !== 'surveySubmit') throw Error('Pembaca akun tidak tersedia.');
    const surveyUnknown = 'Hasil pengiriman survey belum diketahui. Muat ulang status sebelum mengirim kembali.';
    const field = (value, empty = true) => {
      // Backend tuple escaping is unknown: reject delimiters rather than guess.
      if (typeof value !== 'string' || (!empty && !value.trim()) || /["\\\x00-\x1f\x7f]/.test(value)) throw Error('Survey memuat karakter yang belum didukung. Gunakan aplikasi resmi.');
      return value;
    };
    const snapshot = rows => {
      if (!Array.isArray(rows) || !rows.length) throw Error('Pertanyaan survey belum tersedia.');
      const ids = new Set();
      return rows.map(q => {
        const id = field(q?.K_PERTANYAAN, false);
        if (ids.has(id)) throw Error('Pertanyaan survey tidak valid.');
        ids.add(id);
        const options = q.JAWABAN?.JAWABAN_LIST;
        if (!Array.isArray(options) || !options.length) throw Error('Pilihan survey tidak valid.');
        const result = {};
        for (const key of ['K_PERTANYAAN','PERTANYAAN','K_PERTANYAAN_SYARAT','JAWABAN_SYARAT','K_JAWABAN_SYARAT']) result[key] = q[key] ?? '';
        const aids = new Set();
        result.answers = options.map(a => {
          const id = field(a?.K_JAWABAN, false);
          if (aids.has(id)) throw Error('Pilihan survey tidak valid.');
          aids.add(id);
          return Object.fromEntries(['K_JAWABAN','JAWABAN','IS_KETERANGAN','REDIRECT_LINK'].map(k => [k,a[k] ?? '']));
        });
        return result;
      });
    };
    if (action === 'surveySubmit') {
      if (Object.keys(parameters).length !== 3 || parameters.confirmed !== true || !Array.isArray(parameters.questions) || !parameters.questions.length || !Array.isArray(parameters.answers) || parameters.answers.length !== parameters.questions.length) throw Error('Harap mengisi semua pertanyaan');
      const ids = new Set();
      parameters.questions.forEach((q,i) => {
        const a = parameters.answers[i];
        const id = field(q?.K_PERTANYAAN, false);
        field(q?.PERTANYAAN);
        const qkeys = ['K_PERTANYAAN','PERTANYAAN','K_PERTANYAAN_SYARAT','JAWABAN_SYARAT','K_JAWABAN_SYARAT','answers'];
        const akeys = ['K_JAWABAN','JAWABAN','IS_KETERANGAN','REDIRECT_LINK'];
        if (Object.keys(q).length !== qkeys.length || qkeys.some(k => k !== 'answers' && typeof q[k] !== 'string') || !Array.isArray(q.answers)) throw Error('Pertanyaan survey tidak valid.');
        const aids = new Set();
        q.answers.forEach(option => {
          if (!option || Object.keys(option).length !== akeys.length || akeys.some(k => typeof option[k] !== 'string')) throw Error('Pilihan survey tidak valid.');
          const aid = field(option.K_JAWABAN, false);
          if (aids.has(aid)) throw Error('Pilihan survey tidak valid.');
          aids.add(aid);
        });
        if (ids.has(id) || !a || Object.keys(a).length !== 3 || a.question !== id || !Array.isArray(q.answers)) throw Error('Pilihan survey tidak valid.');
        ids.add(id);
        field(a.answer, false); field(a.explanation);
        if (q.answers.filter(v => v?.K_JAWABAN === a.answer).length !== 1) throw Error('Harap mengisi semua pertanyaan');
      });
      if (globalThis.gapuraSurveyInFlight || globalThis.gapuraSurveyUnknown) throw Error(surveyUnknown);
      parameters = JSON.parse(JSON.stringify(parameters));
      globalThis.gapuraSurveyInFlight = true;
      surveyLock = true;
    }
    if (action === 'attendanceSubmit') {
      if (Object.keys(parameters).length !== 4 || parameters.confirmed !== true || typeof parameters.meeting !== 'string' || !parameters.meeting.trim() || !['H','I','S'].includes(parameters.status) || !['0','1'].includes(parameters.mode) || (parameters.status !== 'H' && parameters.mode !== '0')) throw Error('Pilihan presensi tidak valid.');
      if (globalThis.gapuraAttendanceInFlight) throw Error('Presensi sedang dikirim.');
      globalThis.gapuraAttendanceInFlight = true;
      attendanceLock = true;
    }
    let token, username;
    for (let attempt = 0; attempt < 20; attempt++) {
      const kc = typeof KEYCLOAK !== 'undefined' ? KEYCLOAK : null;
      let saved;
      try { saved = JSON.parse(localStorage.getItem('dataAuth') || 'null'); } catch {}
      if (kc?.token && kc?.updateToken && kc?.tokenParsed?.exp * 1000 < Date.now() + 60000) {
        await new Promise((resolve, reject) => {
          const refresh = kc.updateToken(60);
          if (refresh?.then) refresh.then(resolve, reject);
          else if (refresh?.success) refresh.success(resolve).error(() => reject(Error('Sesi UB perlu diperbarui.')));
          else resolve();
        });
      }
      token = kc?.token || saved?.token;
      const claims = kc?.tokenParsed || saved?.tokenParsed;
      username = claims?.preferred_username || saved?.profile?.username;
      if (token) {
        if (claims?.exp && claims.exp * 1000 < Date.now() + 15000) throw Error('Sesi UB kedaluwarsa. Masuk kembali di dashboard resmi.');
        break;
      }
      await new Promise(resolve => setTimeout(resolve, 350));
    }
    if (!token) throw Error('Masuk ke akun.ub.ac.id/dashboard, lalu hubungkan kembali aplikasi Flutter.');
    if (action === 'connection') return {ok:true,data:{connected:true,username:username || ''}};
    const get = async (path, method = 'GET') => {
      const response = await fetch('https://api.ub.ac.id' + path, {
        method, credentials:'omit', redirect:'error',
        cache: ['surveyStatus','surveyQuestions','attendanceMeetings','attendanceSubmit','surveySubmit'].includes(action) ? 'no-store' : 'default',
        headers:{authorization:'Bearer ' + token},
        signal:AbortSignal.timeout(12000)
      });
      const body = await response.text();
      if (body.length > 2000000) throw Error('Respons akun terlalu besar.');
      if (response.headers.get('cf-mitigated') === 'challenge' || /^\s*</.test(body)) throw Error('UB mengembalikan halaman verifikasi, bukan data akun. Muat ulang dashboard resmi.');
      let data;
      try { data = JSON.parse(body); } catch { throw Error('Format respons UB tidak dapat dibaca.'); }
      if (!response.ok) throw Error('Pembacaan akun ditolak UB (HTTP ' + response.status + ').');
      if (!data || typeof data !== 'object' || Array.isArray(data)) throw Error('Format data akun UB tidak dikenali.');
      return data;
    };
    const currentProfile = async () => {
      const result = await get('/mahasiswa/index/getBioMhs_v2', 'POST');
      const rows = result?.mhs?.data;
      if (!Array.isArray(rows) || !rows.length || !rows[0] || typeof rows[0] !== 'object' || Array.isArray(rows[0])) throw Error('Profil mahasiswa UB belum tersedia. Muat profil kembali.');
      return rows[0];
    };
    const contextField = (record, key) => {
      const value = record[key];
      if (!['string','number'].includes(typeof value) || !String(value).trim()) throw Error('Data akademik akun UB belum lengkap. Muat profil dan jadwal kembali.');
      return String(value);
    };
    const gateComplete = async () => {
      const body = await get('/mahasiswa/index/cekStatusSurveyHarian/');
      if (!Array.isArray(body?.output?.data) || body.output.data[0]?.STAT_ISI !== '1') throw Error('Survey kesehatan belum terverifikasi. Muat ulang status.');
    };
    if (action === 'surveyStatus') {
      const data = await get('/mahasiswa/index/cekStatusSurveyHarian/');
      if (surveyReload && !globalThis.gapuraSurveyInFlight && Array.isArray(data?.output?.data) && typeof data.output.data[0]?.STAT_ISI === 'string') globalThis.gapuraSurveyUnknown = false;
      return {ok:true,data};
    }
    if (action === 'surveySubmit') {
      const status = await get('/mahasiswa/index/cekStatusSurveyHarian/');
      const flag = status?.output?.data?.[0]?.STAT_ISI;
      if (!Array.isArray(status?.output?.data) || typeof flag !== 'string' || flag === '1') throw Error('Muat ulang status survey sebelum mengirim.');
      const form = await get('/mahasiswa/index/getPertanyaanSurvey/');
      if (form.status !== 'true') throw Error('Pertanyaan survey belum tersedia.');
      const fresh = snapshot(form?.output?.data);
      if (JSON.stringify(fresh) !== JSON.stringify(parameters.questions)) throw Error('Pertanyaan survey berubah. Muat ulang dan isi kembali.');
      const value = form.output.data.map((q,i) => {
        const a = parameters.answers[i];
        return '(' + [q.K_PERTANYAAN,q.PERTANYAAN,a.answer,a.explanation].map(v => '"' + field(v) + '"').join(', ') + ')';
      }).join(',');
      try {
        const data = await get('/mahasiswa/index/insSurveyKesehatanBulk/?' + new URLSearchParams({data_all:value}));
        const rows = data?.output?.data;
        if (typeof data.status !== 'string' || typeof data.err_msg !== 'string' || !Array.isArray(rows) || !rows.length || rows.some(r => ['ERRSTATE','MESSAGE','ELAPSED_TIME'].some(k => typeof r?.[k] !== 'string'))) throw Error();
        return {ok:true,data};
      } catch {
        globalThis.gapuraSurveyUnknown = true;
        throw Error(surveyUnknown);
      }
    }
    if (action === 'surveyQuestions') return {ok:true,data:await get('/mahasiswa/index/getPertanyaanSurvey/')};
    if (action === 'attendanceSubmit') {
      await gateComplete();
      const profile = await currentProfile();
      const faculty = contextField(profile,'K_FAKULTAS'), branch = contextField(profile,'K_CABANG');
      const body = await get('/mahasiswa/getDataMateriByMhs/?' + new URLSearchParams({is_aktif:'1',k_fakultas:faculty,k_cabang:branch}));
      const rows = body?.output?.data;
      if (!Array.isArray(rows)) throw Error('Data pertemuan belum dapat dibaca.');
      const matches = rows.filter(row => row && String(row.K_MATERI_AJAR ?? '') === parameters.meeting);
      if (matches.length !== 1 || matches[0].K_ABSENSI !== '') throw Error('Pertemuan tidak tersedia untuk presensi. Muat ulang daftar.');
      await gateComplete();
      // Separate state-changing transport: fixed URL, no retry, no redirect.
      const query = new URLSearchParams({k_materi:String(matches[0].K_MATERI_AJAR),k_absensi:parameters.status,keterangan:'',k_fakultas:faculty,k_cabang:branch,is_daring:parameters.mode,catatan:parameters.status === 'H' ? '' : 'catatan'});
      try {
        const response = await fetch('https://api.ub.ac.id/mahasiswa/index/insupdPresensiMhs/?' + query, {
          method:'GET',credentials:'omit',redirect:'error',cache:'no-store',
          headers:{authorization:'Bearer ' + token},signal:AbortSignal.timeout(12000)
        });
        const text = await response.text();
        if (!response.ok || text.length > 2000000) throw Error();
        const data = JSON.parse(text);
        if (!data || typeof data !== 'object' || Array.isArray(data)) throw Error();
        return {ok:true,data};
      } catch {
        throw Error('Hasil pengiriman presensi belum diketahui. Muat ulang status dan daftar sebelum memilih kembali.');
      }
    }
    if (action === 'attendanceMeetings') await gateComplete();
    const schedulePath = '/mahasiswa/getJadwalKuliah/?is_pendek=' + (short && action !== 'history' ? '1' : '0');
    let path;
    if (action === 'identity') return {ok:true,data:await get('/profile', 'POST')};
    if (action === 'profile') return {ok:true,data:await get('/mahasiswa/index/getBioMhs_v2', 'POST')};
    else if (action === 'schedule') path = schedulePath;
    else if (action === 'transcript') path = '/mahasiswa/getKHS/?' + new URLSearchParams(explicitPeriod || {tahun:'x',is_ganjil:'x',is_pendek:short ? '1' : '0'});
    else if (action === 'finance') path = '/mahasiswa/getTagihan/?tahun=x&is_ganjil=x&is_pendek=0';
    else if (action === 'announcements') path = '/mahasiswa/index/getPengumumanMhs/';
    else if (action === 'materials' || action === 'attendanceMeetings') {
      const profile = await currentProfile();
      path = '/mahasiswa/getDataMateriByMhs/?' + new URLSearchParams({
        is_aktif:parameters.active === false ? '0' : '1',
        k_fakultas:contextField(profile,'K_FAKULTAS'),k_cabang:contextField(profile,'K_CABANG')
      });
    }
    else if ((action === 'krs' || action === 'grades') && explicitPeriod) {
      path = '/mahasiswa/' + (action === 'krs' ? 'getKRS' : 'getKHS') + '/?' + new URLSearchParams(explicitPeriod);
    }
    else if (action === 'krs' || action === 'grades' || action === 'history') {
      const schedule = await get(schedulePath);
      const courses = schedule?.jadwal?.data;
      if (!Array.isArray(courses)) throw Error('Format jadwal UB tidak dikenali.');
      if (action === 'history') {
        const chosen = parameters.course;
        if (!chosen || typeof chosen !== 'object' || Array.isArray(chosen)) throw Error('Pilih mata kuliah dari jadwal Anda.');
        const course = courses.find(row => ['K_MK','KELAS','TAHUN','IS_GANJIL'].every(key => String(row[key] ?? '') === String(chosen[key] ?? '')));
        if (!course) throw Error('Mata kuliah tidak ditemukan pada jadwal akun ini.');
        if (course.IS_PENDEK === true || String(course.IS_PENDEK) === '1') throw Error('Riwayat materi semester pendek belum tersedia untuk kontrak ini.');
        const fields = [['k_fakultas','K_FAKULTAS'],['k_jenjang','K_JENJANG'],['k_jurusan','K_JURUSAN'],['k_prog_studi','K_PROG_STUDI'],['k_mk','K_MK'],['thn_mk','THN_MK'],['tahun','TAHUN'],['is_ganjil','IS_GANJIL'],['kelas','KELAS']];
        const branchContext = ['string','number'].includes(typeof course.K_CABANG) && String(course.K_CABANG).trim() ? course : await currentProfile();
        const query = new URLSearchParams(fields.map(([param,key]) => [param,contextField(course,key)]));
        query.set('is_pendek','0');query.set('k_tipe_seleksi','x');query.set('k_cabang',contextField(branchContext,'K_CABANG'));
        path = '/mahasiswa/index/getRiwayatMateriMhs/?' + query;
      } else {
        const term = courses.find(row => row.TAHUN && row.IS_GANJIL !== undefined && row.IS_GANJIL !== null);
        if (!term) throw Error('Semester berjalan belum tersedia pada jadwal Anda.');
        path = '/mahasiswa/' + (action === 'krs' ? 'getKRS' : 'getKHS') + '/?' + new URLSearchParams({tahun:String(term.TAHUN),is_ganjil:String(term.IS_GANJIL),is_pendek:short ? '1' : '0'});
      }
    } else throw Error('Pembaca akun tidak tersedia.');
    return {ok:true,data:await get(path)};
  } catch (error) {
    // Return fixed errors only; error stacks/request options can contain secrets.
    const text = error instanceof Error ? error.message : 'Koneksi akun UB gagal.';
    return {ok:false,error:text.startsWith('Failed to fetch') ? 'Jaringan UB tidak dapat dihubungi dari dashboard resmi.' : text};
  } finally {
    if (attendanceLock) globalThis.gapuraAttendanceInFlight = false;
    if (surveyLock) globalThis.gapuraSurveyInFlight = false;
  }
}

(() => {
  const localOrigins = new Set(['http://127.0.0.1:8790', 'http://localhost:8790']);
  const actions = new Set(['connection','identity','profile','schedule','krs','grades','transcript','finance','announcements','materials','history','surveyStatus','surveyQuestions','attendanceMeetings']);
  let child = null;
  let frame = null;
  window.addEventListener('message', async event => {
    if (!child || event.source !== child || !localOrigins.has(event.origin)) return;
    const message = event.data;
    if (message?.type !== 'GAPURA_ACCOUNT_REQUEST' || (!actions.has(message.action) && message.action !== 'attendanceSubmit' && message.action !== 'surveySubmit') || typeof message.id !== 'string' || message.id.length > 100) return;
    const parameters = message.parameters;
    if (!parameters || typeof parameters !== 'object' || Array.isArray(parameters) || JSON.stringify(parameters).length > 12000) return;
    const result = await readOfficialAccount(message.action, parameters);
    if (event.source === child) child.postMessage({type:'GAPURA_ACCOUNT_RESPONSE',id:message.id,result}, event.origin);
  });
  window.gapuraOpenApp = (mode = 'window') => {
    if (location.origin !== 'https://akun.ub.ac.id' || !location.pathname.startsWith('/dashboard')) throw Error('Open the official UB dashboard first.');
    if (mode === 'iframe') {
      frame?.remove();
      frame = document.createElement('iframe');
      frame.id = 'gapura-flutter-app';
      frame.src = 'http://127.0.0.1:8790';
      frame.title = 'Gapura UB Flutter reconstruction';
      frame.style.cssText = 'position:fixed;inset:0;width:100vw;height:100vh;border:0;z-index:2147483646;background:#0c1524';
      document.body.append(frame);
      child = frame.contentWindow;
    } else {
      child = window.open('http://127.0.0.1:8790', 'gapura-flutter-app');
    }
    return {opened:!!child,mode};
  };
  window.gapuraCloseApp = () => { frame?.remove(); frame=null; child=null; };
})();
