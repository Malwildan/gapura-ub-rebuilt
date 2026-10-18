import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import vm from 'node:vm';

const reader = await fs.readFile(new URL('./session-reader.js', import.meta.url), 'utf8');
const worker = await fs.readFile(new URL('./service-worker.js', import.meta.url), 'utf8');
const officialHelper = await fs.readFile(new URL('./official-session-bridge.js', import.meta.url), 'utf8');
assert.ok(officialHelper.includes(reader.slice(reader.indexOf('async function'))), 'Preview helper must embed the exact shared reader');
const course = {K_MK:'FIXTURE',KELAS:'Z',TAHUN:2031,IS_GANJIL:'0',K_FAKULTAS:'T',K_CABANG:'1',K_JENJANG:'S1',K_JURUSAN:'T',K_PROG_STUDI:'T',K_TIPE_SELEKSI:'T',THN_MK:'2030',IS_PENDEK:'0'};
const calls = [];
const context = vm.createContext({
  location:{origin:'https://akun.ub.ac.id',pathname:'/dashboard'},
  KEYCLOAK:{token:'SYNTHETIC_TEST_TOKEN_ONLY',tokenParsed:{exp:Date.now()/1000+300,preferred_username:'fixture'}},
  localStorage:{getItem:()=>null},
  setTimeout, URLSearchParams, AbortSignal,
  fetch:async(url, options)=>{
    const parsed = new URL(url);
    calls.push({url:parsed,options});
    assert.equal(parsed.origin,'https://api.ub.ac.id');
    assert.equal(options.method,(parsed.pathname.includes('getBioMhs_v2') || parsed.pathname === '/profile')?'POST':'GET');
    assert.equal(options.body,undefined,'Profile POST must have no supplied body');
    assert.equal(options.credentials,'omit');
    assert.equal(options.redirect,'error');
    assert.equal(options.headers.authorization,'Bearer SYNTHETIC_TEST_TOKEN_ONLY');
    const data=parsed.pathname.includes('getJadwal')?{jadwal:{data:[course]}}:
      parsed.pathname.includes('getBioMhs')?{mhs:{data:[{K_FAKULTAS:'T',K_CABANG:'1'}]}}:{fixture:{data:[]}};
    return {ok:true,status:200,headers:{get:()=>null},text:async()=>JSON.stringify(data)};
  }
});
vm.runInContext(reader,context);
const request=(action,parameters={})=>context.readOfficialAccount(action,parameters);
const connection=await request('connection');
assert.equal(connection.ok,true);
assert.equal(connection.data.connected,true);
assert.equal(calls.length,0);
assert.ok(!JSON.stringify(connection).includes('SYNTHETIC_TEST_TOKEN_ONLY'));
const routes={identity:'/profile',profile:'/mahasiswa/index/getBioMhs_v2',schedule:'/mahasiswa/getJadwalKuliah/',transcript:'/mahasiswa/getKHS/',finance:'/mahasiswa/getTagihan/',announcements:'/mahasiswa/index/getPengumumanMhs/',materials:'/mahasiswa/getDataMateriByMhs/'};
for(const [action,path] of Object.entries(routes)){
  assert.equal((await request(action)).ok,true);
  assert.equal(calls.at(-1).url.pathname,path);
}
await request('materials',{active:false});
assert.equal(calls.at(-1).url.searchParams.get('is_aktif'),'0');
assert.equal(calls.at(-1).url.searchParams.get('k_fakultas'),'T');
assert.equal(calls.at(-1).url.searchParams.get('k_cabang'),'1');
for(const action of ['krs','grades']){
  assert.equal((await request(action)).ok,true);
  assert.equal(calls.at(-1).url.searchParams.get('tahun'),'2031');
  assert.equal(calls.at(-1).url.searchParams.get('is_ganjil'),'0');
  assert.equal(calls.at(-1).url.searchParams.get('is_pendek'),'0');
}
assert.equal((await request('schedule',{short:true})).ok,true);
assert.equal(calls.at(-1).url.searchParams.get('is_pendek'),'1');
for (const action of ['krs','grades','transcript']) {
  const count = calls.length;
  assert.equal((await request(action,{short:true,year:'2024',odd:false})).ok,true);
  assert.equal(calls.length,count+1,'Explicit academic period must not fetch or invent a current schedule');
  assert.equal(calls.at(-1).url.searchParams.get('tahun'),'2024');
  assert.equal(calls.at(-1).url.searchParams.get('is_ganjil'),'0');
  assert.equal(calls.at(-1).url.searchParams.get('is_pendek'),'1');
  assert.equal((await request(action,{year:'1900',odd:true})).ok,true);
  assert.equal(calls.at(-1).url.searchParams.get('tahun'),'1900');
  assert.equal(calls.at(-1).url.searchParams.get('is_ganjil'),'1');
  assert.equal(calls.at(-1).url.searchParams.get('is_pendek'),'0');
  assert.equal((await request(action,{year:'2200',odd:false})).ok,true);
  assert.equal(calls.at(-1).url.searchParams.get('tahun'),'2200');
}
for (const action of ['krs','grades']) {
  const count = calls.length;
  assert.equal((await request(action,{short:true})).ok,true);
  assert.equal(calls.length,count+2);
  assert.equal(calls.at(-2).url.pathname,'/mahasiswa/getJadwalKuliah/');
  assert.equal(calls.at(-2).url.searchParams.get('is_pendek'),'1');
  assert.equal(calls.at(-1).url.searchParams.get('tahun'),'2031');
  assert.equal(calls.at(-1).url.searchParams.get('is_pendek'),'1');
}
assert.equal((await request('transcript',{short:true})).ok,true);
assert.equal(calls.at(-1).url.searchParams.get('tahun'),'x');
assert.equal(calls.at(-1).url.searchParams.get('is_ganjil'),'x');
assert.equal(calls.at(-1).url.searchParams.get('is_pendek'),'1');
assert.equal((await request('finance')).ok,true);
assert.equal(calls.at(-1).url.search,'?tahun=x&is_ganjil=x&is_pendek=0');
assert.equal((await request('krs',{year:null,odd:null})).ok,true);
assert.equal(calls.at(-1).url.searchParams.get('tahun'),'2031');
const malformed = [
  {short:'1'},{short:null},{short:1},{short:[]},
  {year:'2024'},{odd:true},{year:null,odd:false},{year:'2024',odd:null},
  {year:2024,odd:true},{year:'2024',odd:'1'},{year:'x',odd:false},
  {year:'1899',odd:true},{year:'2201',odd:false},{year:'02024',odd:true},
  {year:'2024&anything=1',odd:true},{year:' 2024',odd:true}
];
for (const action of ['schedule','krs','grades','transcript','finance']) {
  for (const parameters of malformed) {
    const count=calls.length;
    assert.equal((await request(action,parameters)).ok,false,`${action} must reject ${JSON.stringify(parameters)}`);
    assert.equal(calls.length,count,'Malformed academic selection must fail before any request');
  }
}
{
  const expiry=context.KEYCLOAK.tokenParsed.exp;
  let renewals=0;
  context.KEYCLOAK.tokenParsed.exp=Date.now()/1000-1;
  context.KEYCLOAK.updateToken=()=>{renewals++;throw Error('Invalid selection must not refresh the session');};
  const count=calls.length;
  assert.equal((await request('grades',{year:'not-a-year',odd:true})).ok,false);
  assert.equal(renewals,0,'Selection validation must run before session refresh can request tokens');
  assert.equal(calls.length,count);
  context.KEYCLOAK.tokenParsed.exp=expiry;
  delete context.KEYCLOAK.updateToken;
}
for (const parameters of [{short:true},{year:'2024',odd:true}]) {
  const count=calls.length;
  assert.equal((await request('finance',parameters)).ok,false);
  assert.equal(calls.length,count,'Finance retains its original fixed period without requesting arbitrary terms');
}
{
  const count=calls.length;
  assert.equal((await request('schedule',{year:'2024',odd:true})).ok,false);
  assert.equal(calls.length,count,'Schedule cannot silently ignore an unsupported historical period');
}
{
  const count=calls.length;
  assert.equal((await request('history',{short:true,course})).ok,false);
  assert.equal(calls.length,count,'Unverified short-semester class history must fail before any request');
}
for (const flag of ['1',1,true]) {
  const count=calls.length;
  assert.equal((await request('history',{course:{...course,IS_PENDEK:flag}})).ok,false);
  assert.equal(calls.length,count,'Short course flag must be rejected before any history or schedule request');
}
{
  const count=calls.length;
  const chosen={...course,IS_PENDEK:'0'};
  course.IS_PENDEK='1';
  assert.equal((await request('history',{course:chosen})).ok,false);
  assert.equal(calls.length,count+1,'Matched live short-course metadata must prevent a history request even if caller changes its flag');
  assert.equal(calls.at(-1).url.pathname,'/mahasiswa/getJadwalKuliah/');
  course.IS_PENDEK='0';
}
assert.equal((await request('history',{course})).ok,true);
assert.equal(calls.at(-1).url.pathname,'/mahasiswa/index/getRiwayatMateriMhs/');
assert.equal(calls.at(-1).url.searchParams.get('k_mk'),'FIXTURE');
assert.equal([...calls.at(-1).url.searchParams].length,12);
assert.equal(calls.at(-1).url.searchParams.get('is_pendek'),'0');
assert.equal(calls.at(-1).url.searchParams.get('k_tipe_seleksi'),'x');
assert.equal(calls.at(-1).url.searchParams.get('k_cabang'),'1');
assert.equal((await request('history',{course:{...course,K_MK:'OTHER'}})).ok,false);
const before=calls.length;
assert.equal((await request('attendance')).ok,false);
assert.equal(calls.length,before);
context.KEYCLOAK.tokenParsed.exp=Date.now()/1000-1;
assert.equal((await request('profile')).ok,false);
assert.equal(calls.length,before);

let listener, queried=0, executed=0;
const workerContext=vm.createContext({URL,importScripts:()=>{},chrome:{
  runtime:{onMessage:{addListener:fn=>{listener=fn;}}},
  tabs:{query:async()=>{queried++;return[{id:9,url:'https://akun.ub.ac.id/dashboard'}];}},
  scripting:{executeScript:async options=>{executed++;assert.equal(options.world,'MAIN');assert.equal(options.target.tabId,9);return[{result:{ok:true,data:{connected:true}}}];}}
},readOfficialAccount:()=>{}});
vm.runInContext(worker,workerContext);
assert.equal(listener({type:'GAPURA_ACCOUNT_REQUEST',action:'profile',parameters:{}},{url:'https://unrelated.example/'},()=>{}),false);
assert.equal(listener({type:'GAPURA_ACCOUNT_REQUEST',action:'attendance',parameters:{}},{url:'http://127.0.0.1:8790/'},()=>{}),false);
assert.equal(listener({type:'GAPURA_ACCOUNT_REQUEST',action:'attendanceSubmit',parameters:{confirmed:true,meeting:'SYNTHETIC',status:'H',mode:'0'}},{url:'https://unrelated.example/'},()=>{}),false);
assert.equal(queried,0);
const response=await new Promise(resolve=>{assert.equal(listener({type:'GAPURA_ACCOUNT_REQUEST',action:'connection',parameters:{}},{url:'http://127.0.0.1:8790/'},resolve),true);});
assert.equal(response.ok,true);
assert.equal(queried,1);
assert.equal(executed,1);
console.log('Account bridge checks passed: original profile POST, fixed routes, historical/short academic selections, invalid selections before requests, fixed finance/history contracts, selected-class membership, expired session, token containment, origin/action boundaries.');

// Synthetic-only attendance transport scenarios. This VM has no real fetch.
let flag = '1', recorded = '', available = true, omitProfile = false, writeFails = false, pauseWrite = null;
let gateReads = 0, revokeOnSecond = false;
const attendanceCalls = [];
const attendanceContext = vm.createContext({
  location:{origin:'https://akun.ub.ac.id',pathname:'/dashboard'},
  KEYCLOAK:{token:'SYNTHETIC_ATTENDANCE_TOKEN',tokenParsed:{exp:Date.now()/1000+300}},
  localStorage:{getItem:()=>null},setTimeout,URLSearchParams,AbortSignal,
  fetch:async (url, options) => {
    const parsed = new URL(url);
    attendanceCalls.push({url:parsed,options});
    assert.equal(parsed.origin,'https://api.ub.ac.id');
    assert.equal(options.redirect,'error');
    assert.equal(options.body,undefined);
    assert.equal(options.credentials,'omit');
    assert.equal(options.headers.authorization,'Bearer SYNTHETIC_ATTENDANCE_TOKEN');
    let data;
    if (parsed.pathname.includes('cekStatus')) {
      gateReads++;
      assert.equal(parsed.search,'');
      assert.equal(options.cache,'no-store');
      data={output:{data:[{STAT_ISI:revokeOnSecond && gateReads === 2 ? '0' : flag}]}};
    } else if (parsed.pathname.includes('getPertanyaan')) {
      assert.equal(parsed.search,'');data={status:'true',output:{data:[]}};
    } else if (parsed.pathname.includes('getBio')) {
      assert.equal(options.method,'POST');
      data={mhs:{data:[omitProfile ? {} : {K_FAKULTAS:'SYNTHETIC-F',K_CABANG:'SYNTHETIC-B'}]}};
    } else if (parsed.pathname.includes('getDataMateri')) {
      assert.equal(parsed.searchParams.get('k_fakultas'),'SYNTHETIC-F');
      assert.equal(parsed.searchParams.get('k_cabang'),'SYNTHETIC-B');
      data={output:{data:available ? [{K_MATERI_AJAR:'SYNTHETIC-ID&= /',K_ABSENSI:recorded}] : []}};
    } else {
      assert.equal(parsed.pathname,'/mahasiswa/index/insupdPresensiMhs/');
      assert.equal(options.method,'GET');
      assert.equal(options.cache,'no-store');
      if (pauseWrite) await pauseWrite;
      if (writeFails) throw Error('SYNTHETIC_NETWORK_ERROR_WITH_PRIVATE_REQUEST_DETAILS');
      data={mhs:{data:[{ERRSTATE:'00000'}]}};
    }
    return {ok:true,status:200,headers:{get:()=>null},text:async()=>JSON.stringify(data)};
  }
});
vm.runInContext(reader,attendanceContext);
const attendanceRequest=(action,parameters={})=>attendanceContext.readOfficialAccount(action,parameters);
const chosen={confirmed:true,meeting:'SYNTHETIC-ID&= /',status:'H',mode:'0'};
const mutationCount=()=>attendanceCalls.filter(c=>c.url.pathname.includes('insupd')).length;
assert.equal((await attendanceRequest('surveyStatus')).ok,true);
assert.equal((await attendanceRequest('surveyQuestions')).ok,true);
assert.equal((await attendanceRequest('attendanceMeetings',{active:false})).ok,true);
assert.equal(attendanceCalls.at(-1).url.searchParams.get('is_aktif'),'0');
assert.equal(mutationCount(),0,'Opening reads never dispatches mutations');
for (const [status,mode] of [['H','0'],['H','1'],['I','0'],['S','0']]) {
  const start=attendanceCalls.length;
  assert.equal((await attendanceRequest('attendanceSubmit',{...chosen,status,mode})).ok,true);
  const wire=attendanceCalls.slice(start);
  assert.deepEqual(wire.map(c=>c.url.pathname),['/mahasiswa/index/cekStatusSurveyHarian/','/mahasiswa/index/getBioMhs_v2','/mahasiswa/getDataMateriByMhs/','/mahasiswa/index/cekStatusSurveyHarian/','/mahasiswa/index/insupdPresensiMhs/']);
  assert.deepEqual(Object.fromEntries(wire.at(-1).url.searchParams),{k_materi:chosen.meeting,k_absensi:status,keterangan:'',k_fakultas:'SYNTHETIC-F',k_cabang:'SYNTHETIC-B',is_daring:mode,catatan:status==='H'?'':'catatan'});
}
for (const bad of [{...chosen,confirmed:false},{...chosen,status:'A'},{...chosen,status:'I',mode:'1'},{...chosen,mode:1},{...chosen,meeting:''},{...chosen,url:'https://example.invalid'}]) {
  const count=attendanceCalls.length;
  assert.equal((await attendanceRequest('attendanceSubmit',bad)).ok,false);
  assert.equal(attendanceCalls.length,count,'Invalid choice rejected before any network call');
}
for (const invalidFlag of ['0','',1,true,null,undefined]) {
  flag=invalidFlag;
  const writes=mutationCount();
  assert.equal((await attendanceRequest('attendanceSubmit',chosen)).ok,false);
  assert.equal((await attendanceRequest('attendanceMeetings')).ok,false);
  assert.equal(mutationCount(),writes);
}
flag='1';
for (const scenario of ['forged','recorded','missing','profile','revoked']) {
  recorded=scenario==='recorded'?'H':'';
  available=scenario!=='missing';omitProfile=scenario==='profile';revokeOnSecond=scenario==='revoked';gateReads=0;
  const writes=mutationCount();
  assert.equal((await attendanceRequest('attendanceSubmit',scenario==='forged'?{...chosen,meeting:'FORGED'}:chosen)).ok,false);
  assert.equal(mutationCount(),writes);
}
recorded='';available=true;omitProfile=false;revokeOnSecond=false;
writeFails=true;
const beforeFailure=mutationCount();
const failed=await attendanceRequest('attendanceSubmit',chosen);
assert.equal(failed.ok,false);
assert.ok(failed.error.includes('belum diketahui'));
assert.ok(!JSON.stringify(failed).includes('PRIVATE_REQUEST'));
assert.equal(mutationCount(),beforeFailure+1,'Unknown outcome must never retry');
writeFails=false;
let release;
pauseWrite=new Promise(resolve=>{release=resolve;});
const first=attendanceRequest('attendanceSubmit',chosen);
for(let i=0;i<20 && !attendanceCalls.at(-1).url.pathname.includes('insupd');i++) await Promise.resolve();
assert.equal((await attendanceRequest('attendanceSubmit',chosen)).ok,false,'Concurrent explicit actions must not duplicate a write');
release();
assert.equal((await first).ok,true);
pauseWrite=null;
assert.ok(!JSON.stringify(await attendanceRequest('surveyStatus')).includes('SYNTHETIC_ATTENDANCE_TOKEN'));
console.log('Attendance bridge checks passed: 4 original callback mappings, 6 invalid choices, 6 strict non-complete gate values, 5 context rejection cases, read-only opening, fresh status, no retry, concurrency, encoding, fixed mutation URL, token containment.');

// Synthetic survey transport only: no real networking is present in this VM.
const surveyForm = () => ['Q2','Q1'].map(id => ({K_PERTANYAAN:id,PERTANYAAN:'<p>é 健康 & ? # = + % ('+id+')</p>',JAWABAN:{JAWABAN_LIST:[{K_JAWABAN:'A'+id,JAWABAN:'Synthetic '+id,IS_KETERANGAN:'1',REDIRECT_LINK:'https://example.invalid'}]}}));
const surveySnapshot = rows => rows.map(q => ({K_PERTANYAAN:q.K_PERTANYAAN,PERTANYAAN:q.PERTANYAAN,K_PERTANYAAN_SYARAT:'',JAWABAN_SYARAT:'',K_JAWABAN_SYARAT:'',answers:q.JAWABAN.JAWABAN_LIST.map(a=>({...a}))}));
const surveyParams = () => ({confirmed:true,questions:surveySnapshot(surveyForm()),answers:surveyForm().map(q=>({question:q.K_PERTANYAAN,answer:'A'+q.K_PERTANYAAN,explanation:'é 健康 & = # ? + % , ()'}))});
const surveyResult = () => ({status:'true',err_msg:'',output:{data:[{ERRSTATE:'any',MESSAGE:'Synthetic only',ELAPSED_TIME:'0'}]}});
let surveyFlag='0', freshForm=surveyForm(), surveyFail=false, malformedSave=false, holdSurvey=null;
let surveyRenewals=0;
const surveyCalls=[];
const surveyContext=vm.createContext({
  location:{origin:'https://akun.ub.ac.id',pathname:'/dashboard'},
  KEYCLOAK:{token:'SYNTHETIC_SURVEY_TOKEN',tokenParsed:{exp:Date.now()/1000+300},updateToken:async()=>{surveyRenewals++;}},
  localStorage:{getItem:()=>null},setTimeout,URLSearchParams,AbortSignal,
  fetch:async(url,options)=>{
    const parsed=new URL(url);surveyCalls.push({url:parsed,options});
    assert.equal(options.method,'GET');assert.equal(options.body,undefined);
    assert.equal(options.credentials,'omit');assert.equal(options.redirect,'error');assert.equal(options.cache,'no-store');
    assert.deepEqual({...options.headers},{authorization:'Bearer SYNTHETIC_SURVEY_TOKEN'});
    let data;
    if(parsed.pathname.includes('cekStatus')) {assert.equal(parsed.search,'');data={output:{data:[{STAT_ISI:surveyFlag}]}};}
    else if(parsed.pathname.includes('getPertanyaan')) {assert.equal(parsed.search,'');data={status:'true',output:{data:freshForm}};}
    else {
      assert.equal(parsed.pathname,'/mahasiswa/index/insSurveyKesehatanBulk/');
      if(holdSurvey)await holdSurvey;
      if(surveyFail)throw Error('PRIVATE_ANSWERS_URL_TOKEN');
      data=malformedSave?{}:surveyResult();
    }
    return {ok:true,status:200,headers:{get:()=>null},text:async()=>JSON.stringify(data)};
  }
});
vm.runInContext(reader,surveyContext);
const surveyRequest=(action,p={})=>surveyContext.readOfficialAccount(action,p);
const surveyWrites=()=>surveyCalls.filter(c=>c.url.pathname.includes('insSurvey')).length;
assert.equal((await surveyRequest('surveyStatus')).ok,true);
assert.equal((await surveyRequest('surveyQuestions')).ok,true);
assert.equal(surveyWrites(),0);
const startSurvey=surveyCalls.length;
assert.equal((await surveyRequest('surveySubmit',surveyParams())).ok,true);
assert.deepEqual(surveyCalls.slice(startSurvey).map(c=>c.url.pathname),['/mahasiswa/index/cekStatusSurveyHarian/','/mahasiswa/index/getPertanyaanSurvey/','/mahasiswa/index/insSurveyKesehatanBulk/']);
const surveyWire=surveyCalls.at(-1).url;
assert.deepEqual([...surveyWire.searchParams.keys()],['data_all']);
assert.equal(surveyWire.hash,'');
assert.equal(surveyWire.searchParams.get('data_all'),surveyForm().map(q=>'("'+q.K_PERTANYAAN+'", "'+q.PERTANYAAN+'", "A'+q.K_PERTANYAAN+'", "é 健康 & = # ? + % , ()")').join(','));
const invalidSurvey=[];
invalidSurvey.push({...surveyParams(),confirmed:false},{...surveyParams(),url:'https://example.invalid'});
for(const answer of [null,'','FORGED']){const p=surveyParams();p.answers[0].answer=answer;invalidSurvey.push(p);}
for(const char of ['"','\\','\n','\r','\t','\x00','\x1f','\x7f']) {
  for(const key of ['question','answer','explanation']) {const p=surveyParams();p.answers[0][key]=char;invalidSurvey.push(p);}
}
for(const p of invalidSurvey){
  const count=surveyCalls.length;surveyContext.KEYCLOAK.tokenParsed.exp=Date.now()/1000-1;
  assert.equal((await surveyRequest('surveySubmit',p)).ok,false);
  assert.equal(surveyCalls.length,count);assert.equal(surveyRenewals,0,'Invalid caller must fail before refresh');
}
surveyContext.KEYCLOAK.tokenParsed.exp=Date.now()/1000+300;
for(const change of ['order','question','answer','metadata','empty','duplicate','unsafe']) {
  freshForm=surveyForm();
  if(change==='order')freshForm.reverse();
  if(change==='question')freshForm[0].PERTANYAAN='Changed';
  if(change==='answer')freshForm[0].JAWABAN.JAWABAN_LIST[0].K_JAWABAN='NEW';
  if(change==='metadata')freshForm[0].JAWABAN.JAWABAN_LIST[0].IS_KETERANGAN='0';
  if(change==='empty')freshForm=[];
  if(change==='duplicate')freshForm=[freshForm[0],freshForm[0]];
  if(change==='unsafe')freshForm[0].PERTANYAAN='Unsafe"';
  const count=surveyWrites();assert.equal((await surveyRequest('surveySubmit',surveyParams())).ok,false);assert.equal(surveyWrites(),count);
}
freshForm=surveyForm();
for(const flag of ['1',1,true,null]) {
  surveyFlag=flag;const count=surveyWrites();assert.equal((await surveyRequest('surveySubmit',surveyParams())).ok,false);assert.equal(surveyWrites(),count);
}
surveyFlag='0';
for(const scenario of ['network','malformed']){
  surveyFail=scenario==='network';malformedSave=scenario==='malformed';
  const count=surveyWrites();const result=await surveyRequest('surveySubmit',surveyParams());
  assert.equal(result.ok,false);assert.ok(result.error.includes('belum diketahui'));assert.ok(!JSON.stringify(result).includes('PRIVATE_ANSWERS'));
  assert.equal(surveyWrites(),count+1,'Never retry');
  assert.equal((await surveyRequest('surveySubmit',surveyParams())).ok,false);assert.equal(surveyWrites(),count+1);
  surveyFlag=1;await surveyRequest('surveyStatus');assert.equal((await surveyRequest('surveySubmit',surveyParams())).ok,false);
  surveyFlag='0';await surveyRequest('surveyStatus');
}
surveyFail=false;malformedSave=false;
let releaseSurvey;holdSurvey=new Promise(resolve=>{releaseSurvey=resolve;});
const surveyFirst=surveyRequest('surveySubmit',surveyParams());
for(let i=0;i<30&&!surveyCalls.at(-1).url.pathname.includes('insSurvey');i++)await Promise.resolve();
// Change auth context while pending: same global guard must still reject it.
surveyContext.KEYCLOAK.token='SYNTHETIC_OTHER_CONTEXT';
assert.equal((await surveyRequest('surveySubmit',surveyParams())).ok,false);
surveyContext.KEYCLOAK.token='SYNTHETIC_SURVEY_TOKEN';
releaseSurvey();assert.equal((await surveyFirst).ok,true);
assert.ok(!JSON.stringify(await surveyRequest('surveyStatus')).includes('SYNTHETIC_SURVEY_TOKEN'));
console.log('Survey bridge checks passed: fixed encoded GET/Bearer only, raw ordered tuples, '+invalidSurvey.length+' pre-refresh invalid cases, 7 changed forms, 4 invalid gates, transport/malformed unknown outcomes, explicit reload, no retry and cross-auth concurrency.');

// Worker guard spans official dashboard tabs, and ignores stale status reloads.
let workerSurveyListener, workerWriteResolve, workerStatusResolve;
let workerHoldStatus=false, workerQueryCount=0;
const workerSurveyContext=vm.createContext({URL,importScripts:()=>{},readOfficialAccount:()=>{},chrome:{
  runtime:{onMessage:{addListener:fn=>{workerSurveyListener=fn;}}},
  tabs:{query:async()=>[{id:++workerQueryCount,url:'https://akun.ub.ac.id/dashboard'}]},
  scripting:{executeScript:async options=>{
    if(options.args[0]==='surveySubmit')return new Promise(resolve=>{workerWriteResolve=resolve;});
    if(workerHoldStatus)return new Promise(resolve=>{workerStatusResolve=resolve;});
    return [{result:{ok:true,data:{output:{data:[{STAT_ISI:'0'}]}}}}];
  }}}
});
vm.runInContext(worker,workerSurveyContext);
const workerSurveyRequest=(action,p={})=>new Promise(resolve=>workerSurveyListener({type:'GAPURA_ACCOUNT_REQUEST',action,parameters:p},{url:'http://127.0.0.1:8790/'},resolve));
const workerFirst=workerSurveyRequest('surveySubmit',surveyParams());
for(let i=0;i<20&&!workerWriteResolve;i++)await Promise.resolve();
assert.equal((await workerSurveyRequest('surveySubmit',surveyParams())).ok,false,'A second auth tab must not receive a write');
workerHoldStatus=true;
const workerStale=workerSurveyRequest('surveyStatus');
for(let i=0;i<20&&!workerStatusResolve;i++)await Promise.resolve();
workerWriteResolve([{result:{ok:false,error:'Hasil pengiriman survey belum diketahui.'}}]);
assert.equal((await workerFirst).ok,false);
workerStatusResolve([{result:{ok:true,data:{output:{data:[{STAT_ISI:'0'}]}}}}]);
await workerStale;
assert.equal((await workerSurveyRequest('surveySubmit',surveyParams())).ok,false,'Stale read must not clear unknown');
workerHoldStatus=false;await workerSurveyRequest('surveyStatus');
workerWriteResolve=null;
const workerAgain=workerSurveyRequest('surveySubmit',surveyParams());
for(let i=0;i<20&&!workerWriteResolve;i++)await Promise.resolve();
workerWriteResolve([{result:{ok:true,data:surveyResult()}}]);
assert.equal((await workerAgain).ok,true);
console.log('Survey extension worker checks passed: global concurrency across dashboard/auth tabs, unknown outcome, stale status race and explicit reload recovery.');
