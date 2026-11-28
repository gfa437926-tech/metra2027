// whatsapp-sender.js - نظام مشاركة التقارير عبر واتساب
console.log('🔄 تحميل نظام مشاركة واتساب...');
const whatsappSender = {
    createWhatsappMessage: function(formData, userData) {
        const currentDate = document.getElementById('currentDate').value;
        const currentTime = document.getElementById('currentTime').value;
        return `🌤️ *التقرير الساعي للطقس - المركز الوطني للأرصاد الجوية*\n\n📊 *معلومات الرصد*\n👤 الراصد: ${userData.userName}\n🏢 المحطة: ${userData.stationName}\n📅 التاريخ: ${currentDate}\n⏰ الوقت: ${currentTime}\n🕐 التوقيت العالمي: ${formData.utcTime || ''}:00 (UTC)\n\n🌡️ *البيانات الجوية*\n🌡️ الحرارة الجافة: ${formData.dryTemp || ''} °C\n💧 الحرارة الرطبة: ${formData.wetTemp || ''} °C\n💦 الرطوبة النسبية: ${formData.relativeHumidity || ''}%\n🌫️ درجة الندى: ${formData.dewPoint || ''} °C\n\n📊 *الضغط الجوي*\n🔽 ضغط المحطة: ${formData.stationPressure || ''} مليبار\n🔼 ضغط سطح البحر: ${formData.seaLevelPressure || ''} مليبار\n\n💨 *الرياح*\n🧭 الاتجاه السطحي: ${formData.windDirection || ''}° (عشرات)\n🌬️ السرعة السطحية: ${formData.windSpeed || ''} م/ثا\n🧭 متوسط الاتجاه: ${formData.avgWindDirection || ''}°\n🌬️ متوسط السرعة: ${formData.avgWindSpeed || ''} م/ثا\n\n👁️ *الرؤية والطقس*\n👀 الرؤية: ${formData.visibility || ''} (مئات الأمتار)\n☁️ الطقس الحاضر (كود): ${formData.currentWeather || ''}\n⏪ الطقس الغابر (كود): ${formData.pastWeather || ''}\n\n🌧️ *الهطول*\n💧 كمية الهطول: ${formData.precipitationAmount || '0'} ملم\n\n☁️ *السحب*\n📊 التغطية الكلية: ${formData.totalCloudCover || ''}/8\n🏔️ الطبقة 1: ${formData.cloud1Amount || '0'}/8 ${formData.cloud1Type || ''}\n🏔️ ارتفاع: ${formData.cloud1Height || ''}0 م\n🏔️ الطبقة 2: ${formData.cloud2Amount || '0'}/8 ${formData.cloud2Type || ''}\n🏔️ ارتفاع: ${formData.cloud2Height || ''}0 م\n\n📝 *ملاحظات الراصد*\n${formData.observerNotes || 'لا توجد ملاحظات'}\n\n---\n*المركز الوطني للأرصاد الجوية*\n*${new Date().toLocaleString('ar-SA')}*`;
    },
    shareViaWhatsapp: function() {
        console.log('📱 مشاركة عبر واتساب...');
        const required = ['utcTime','dryTemp','wetTemp','stationPressure','seaLevelPressure','windDirection','windSpeed','visibility'];
        let valid=true;
        for(let id of required){ const f=document.getElementById(id); if(f){ const v=f.value?.trim()||''; if(v===''||v==='#'){ valid=false; f.classList.add('is-invalid'); }else f.classList.remove('is-invalid'); } }
        if(!valid){ if(window.showNotification) window.showNotification('❌ يرجى ملء الحقول المطلوبة قبل المشاركة','error'); return; }
        let fd = window.collectFormData ? window.collectFormData() : this.collectFormDataManually();
        let ud = window.getCurrentUserData ? window.getCurrentUserData() : this.getUserDataManually();
        const msg = this.createWhatsappMessage(fd,ud);
        this.openWhatsapp(msg);
        if(window.showNotification) window.showNotification('✅ تم فتح واتساب مع نص التقرير','success');
    },
    collectFormDataManually: function() { const f=document.getElementById('hourlyReportForm'); if(!f) return {}; const d={}; f.querySelectorAll('input,select,textarea').forEach(i=>{ if(i.name&&i.name.trim()) d[i.name]=i.value||''; }); return d; },
    getUserDataManually: function() { try { const ud=localStorage.getItem('currentUser'); if(!ud) return {userName:'مستخدم النظام',stationName:'المحطة الرئيسية'}; const u=JSON.parse(ud); const name=[u.first_name,u.father_name,u.last_name].filter(n=>n&&n.trim()).join(''); return {userName:name||u.email||'مستخدم النظام',stationName:u.station||'المحطة الرئيسية'}; } catch(e){ return {userName:'مستخدم النظام',stationName:'المحطة الرئيسية'}; } },
    openWhatsapp: function(msg) { window.open(`https://wa.me/?text=${encodeURIComponent(msg)}`,'_blank'); },
    startSharing: function() { if(window.forceFormatAllFields) window.forceFormatAllFields(); setTimeout(()=>this.shareViaWhatsapp(),300); }
};
if(typeof window !== 'undefined') window.whatsappSender = whatsappSender;
document.addEventListener('DOMContentLoaded', function() { const btn=document.getElementById('shareWhatsappBtn'); if(btn) btn.addEventListener('click',e=>{ e.preventDefault(); if(window.whatsappSender) window.whatsappSender.startSharing(); }); const pbtn=document.getElementById('whatsappPreviewBtn'); if(pbtn) pbtn.addEventListener('click',e=>{ e.preventDefault(); if(window.whatsappSender) window.whatsappSender.startSharing(); }); console.log('✅ نظام مشاركة واتساب جاهز'); });