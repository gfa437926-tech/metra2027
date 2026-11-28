// submit-hourly.js - النسخة النهائية مع دعم # (بدون raw_data)
console.log('🔄 تحميل submit-hourly.js (النسخة النهائية مع دعم #)');

let isSubmitting = false;

async function checkSupabaseConnection() {
    if (!window.supabase) return false;
    try {
        const { error } = await window.supabase.from('hourly_reports').select('id').limit(1).maybeSingle();
        if (error && error.code !== 'PGRST116') return false;
        return true;
    } catch (e) { return false; }
}

function collectFormData() {
    const form = document.getElementById('hourlyReportForm');
    if (!form) return {};
    const data = {};
    form.querySelectorAll('input, select, textarea').forEach(inp => { if(inp.name && inp.name.trim()) data[inp.name] = inp.value || ''; });
    ['relativeHumidity','dewPoint','vaporPressure','vaporPressureDiff','pressureSlope','pressureShape','precipitationAmount'].forEach(f => { const el = document.getElementById(f); if(el) data[f] = el.value || ''; });
    return data;
}

function getCurrentUserData() {
    try {
        const ud = localStorage.getItem('currentUser');
        if (!ud) return { userName:'مستخدم', stationName:'غير محدد', userRole:'راصد', userId:'unknown', userEmail:'unknown' };
        const u = JSON.parse(ud);
        const name = [u.first_name,u.father_name,u.last_name].filter(n=>n&&n.trim()).join(' ');
        return { userName: name||u.email||'مستخدم', stationName: u.station||'المحطة الرئيسية', userRole: u.role||'راصد جوي', userId: u.id||'unknown', userEmail: u.email||'unknown' };
    } catch(e) { return { userName:'مستخدم', stationName:'المحطة', userRole:'راصد', userId:'unknown', userEmail:'unknown' }; }
}

function generateReportId() { return `HR_${Date.now()}_${Math.random().toString(36).substring(2,9)}`; }

function validateForm() {
    let valid = true;
    const required = ['utcTime','dryTemp','wetTemp','stationPressure','seaLevelPressure','windDirection','windSpeed','visibility','totalCloudCover','relativeHumidity','dewPoint'];
    for (let id of required) {
        let f = document.getElementById(id);
        if (f && f.required) {
            let val = f.value?.trim() || '';
            if (val === '') { f.classList.add('is-invalid'); valid = false; }
            else f.classList.remove('is-invalid');
        }
    }
    let utc = document.getElementById('utcTime');
    if (utc && utc.value && ['00','06','12','18'].includes(utc.value.padStart(2,'0'))) {
        let p = document.getElementById('precipitationAmount');
        if (p && p.required && (!p.value || p.value.trim() === '')) { p.classList.add('is-invalid'); valid = false; }
    }
    let agree = document.getElementById('responsibilityAgreement');
    if (agree && !agree.checked) { agree.classList.add('is-invalid'); valid = false; }
    if (!valid) showNotification('يرجى تصحيح الحقول الحمراء (يمكن استخدام #)', 'error');
    return valid;
}

function validateTemperatureRelationship() {
    let d = document.getElementById('dryTemp')?.value?.trim(), w = document.getElementById('wetTemp')?.value?.trim();
    if (!d || !w || d==='#' || w==='#') return true;
    let dn=parseFloat(d), wn=parseFloat(w);
    if(isNaN(dn)||isNaN(wn)) return true;
    if(dn<wn){ showNotification('❌ الحرارة الجافة يجب أن تكون ≥ الحرارة الرطبة','error'); return false; }
    return true;
}

function prepareReportData(fd, ud) {
    const now = new Date();
    return {
        utc_time: fd.utcTime || '', dry_temp: fd.dryTemp || '', wet_temp: fd.wetTemp || '', dew_point: fd.dewPoint || '',
        station_pressure: fd.stationPressure || '', sea_level_pressure: fd.seaLevelPressure || '', relative_humidity: fd.relativeHumidity || '',
        vapor_pressure: fd.vaporPressure || '', vapor_pressure_diff: fd.vaporPressureDiff || '', wind_direction: fd.windDirection || '',
        wind_speed: fd.windSpeed || '', avg_wind_direction: fd.avgWindDirection || '', avg_wind_speed: fd.avgWindSpeed || '',
        visibility: fd.visibility || '', current_weather: fd.currentWeather || '', past_weather: fd.pastWeather || '',
        total_cloud_cover: fd.totalCloudCover || '', cloud1_amount: fd.cloud1Amount || '', cloud1_type: fd.cloud1Type || '',
        cloud1_height: fd.cloud1Height || '', cloud2_amount: fd.cloud2Amount || '', cloud2_type: fd.cloud2Type || '',
        cloud2_height: fd.cloud2Height || '', cloud3_amount: fd.cloud3Amount || '', cloud3_type: fd.cloud3Type || '',
        cloud3_height: fd.cloud3Height || '', cloud4_amount: fd.cloud4Amount || '', cover12: fd.cover12 || '',
        cover123: fd.cover123 || '', pressure_slope: fd.pressureSlope || '', pressure_shape: fd.pressureShape || '',
        precipitation_amount: fd.precipitationAmount || '', observer_notes: fd.observerNotes || '',
        user_id: ud.userId, user_email: ud.userEmail, user_name: ud.userName, station_name: ud.stationName, user_role: ud.userRole,
        report_id: generateReportId(), submission_date: now.toLocaleDateString('en-CA'), submission_time: now.toLocaleTimeString('en-US',{hour12:false, hour:'2-digit', minute:'2-digit', second:'2-digit'}),
        report_type:'hourly', status:'submitted', validation_status:'pending', created_at: now.toISOString(), updated_at: now.toISOString()
    };
}

async function saveLocalBackup(data, tableName, err=null) {
    try {
        const key = `${tableName}_backup`;
        const backups = JSON.parse(localStorage.getItem(key) || '[]');
        const backup = { ...data, local_saved_at: new Date().toISOString(), backup_id: `backup_${Date.now()}_${Math.random().toString(36).substr(2,9)}`, synced: false, table_name: tableName, error_message: err };
        backups.push(backup);
        localStorage.setItem(key, JSON.stringify(backups));
        if(window.scheduleSyncWithSupabase) window.scheduleSyncWithSupabase();
        return { success: true, message: 'تم حفظ نسخة احتياطية محلياً', source:'local_backup' };
    } catch(e) { return { success: false, message: e.message }; }
}

async function submitHourlyReport() {
    if(isSubmitting){ showNotification('جاري الإرسال حالياً...','warning'); return {success:false}; }
    isSubmitting=true;
    toggleLoading(true);
    try {
        if(!validateForm()) throw new Error('البيانات غير صالحة');
        if(!validateTemperatureRelationship()) throw new Error('خطأ في درجات الحرارة');
        const fd = collectFormData(), ud = getCurrentUserData(), rd = prepareReportData(fd,ud);
        const conn = await checkSupabaseConnection();
        let result;
        if(conn && window.sendToDatabase) result = await window.sendToDatabase(rd,'hourly_reports');
        else { result = await saveLocalBackup(rd,'hourly_reports'); result.message = 'تم حفظ التقرير محلياً (قاعدة البيانات غير متاحة)'; }
        if(result.success) { showNotification(result.message,'success'); setTimeout(()=>resetForm(),2000); }
        else showNotification(result.message,'error');
        return result;
    } catch(err) { showNotification(err.message,'error'); return {success:false, message:err.message}; }
    finally { toggleLoading(false); isSubmitting=false; }
}

function resetForm() { const f=document.getElementById('hourlyReportForm'); if(f) f.reset(); document.querySelectorAll('input,select,textarea').forEach(el=>el.classList.remove('is-invalid','is-valid')); const a=document.getElementById('responsibilityAgreement'); if(a) a.checked=false; }
function toggleLoading(show) { const ov=document.getElementById('loadingOverlay'); if(ov) ov.style.display=show?'flex':'none'; }
function showNotification(msg,type='info') { const c=document.getElementById('notificationContainer'); if(!c){ console.log(msg); return; } const cls=type==='error'?'alert-danger':type==='success'?'alert-success':'alert-info'; const icon=type==='success'?'fa-check-circle':type==='error'?'fa-exclamation-circle':'fa-info-circle'; const n=document.createElement('div'); n.className=`alert ${cls} alert-dismissible fade show`; n.innerHTML=`<i class="fas ${icon} me-2"></i>${msg}<button type="button" class="btn-close" data-bs-dismiss="alert"></button>`; c.appendChild(n); setTimeout(()=>n.remove(),5000); }
function attachSubmitHandler() { const btn=document.getElementById('submitReportBtn'); if(btn){ btn.onclick=async(e)=>{ e.preventDefault(); await submitHourlyReport(); }; console.log('✅ تم ربط زر الإرسال'); } }
if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',attachSubmitHandler); else attachSubmitHandler();
window.submitHourlyReport=submitHourlyReport; window.validateForm=validateForm; window.showNotification=showNotification;
console.log('✅ submit-hourly.js جاهز (يدعم #)');