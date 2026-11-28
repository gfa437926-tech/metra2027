// data-collector.js - نظام جمع البيانات وعرض المعاينة
console.log('🔄 تحميل نظام جمع البيانات...');

const dataCollector = {
    collectFormData: function() {
        console.log('📝 جمع بيانات النموذج...');
        const form = document.getElementById('hourlyReportForm');
        if (!form) { console.error('❌ لم يتم العثور على النموذج'); return {}; }
        const data = {};
        const inputs = form.querySelectorAll('input, select, textarea');
        inputs.forEach(input => { if (input.name && input.name.trim() !== '') data[input.name] = input.value || ''; });
        const additionalFields = ['relativeHumidity', 'dewPoint', 'vaporPressure', 'vaporPressureDiff', 'pressureSlope', 'pressureShape', 'precipitationAmount'];
        additionalFields.forEach(field => { const element = document.getElementById(field); if (element) data[field] = element.value || ''; });
        console.log('📊 بيانات النموذج المجمعة:', data);
        return data;
    },
    getUserData: function() {
        try {
            const userDataStr = localStorage.getItem('currentUser');
            if (!userDataStr) return { userName: 'مستخدم غير معروف', stationName: 'غير محدد', userRole: 'غير محدد' };
            const userData = JSON.parse(userDataStr);
            const userName = [userData.first_name, userData.father_name, userData.last_name].filter(name => name && name.trim() !== '').join(' ');
            return { userName: userName || userData.email || 'مستخدم النظام', stationName: userData.station || 'المحطة الرئيسية', userRole: userData.role || 'راصد جوي', userId: userData.id || 'unknown', userEmail: userData.email || 'unknown@example.com' };
        } catch (error) { console.error('❌ خطأ في جلب بيانات المستخدم:', error); return { userName: 'مستخدم النظام', stationName: 'المحطة الرئيسية', userRole: 'راصد جوي' }; }
    },
    createPreviewContent: function(formData, userData) {
        const currentDate = document.getElementById('currentDate').value;
        const currentTime = document.getElementById('currentTime').value;
        return `
            <div class="preview-container">
                <div class="preview-section"><h5><i class="fas fa-user-tie"></i> معلومات الراصد</h5><div class="row"><div class="col-md-6"><p><strong>👤 الراصد:</strong> ${userData.userName}</p><p><strong>🏢 المحطة:</strong> ${userData.stationName}</p><p><strong>👔 صفة العمل:</strong> ${userData.userRole}</p></div><div class="col-md-6"><p><strong>📅 التاريخ:</strong> ${currentDate}</p><p><strong>⏰ الوقت الحالي:</strong> ${currentTime}</p><p><strong>🕐 وقت الرصد:</strong> ${formData.utcTime || ''}:00 (توقيت عالمي)</p></div></div></div>
                <div class="preview-section"><h5><i class="fas fa-thermometer-half"></i> درجات الحرارة</h5><div class="row"><div class="col-md-4"><p><strong>🌡️ الحرارة الجافة:</strong> ${formData.dryTemp || ''} °C</p></div><div class="col-md-4"><p><strong>💧 الحرارة الرطبة:</strong> ${formData.wetTemp || ''} °C</p></div><div class="col-md-4"><p><strong>🌫️ درجة الندى:</strong> ${formData.dewPoint || ''} °C</p></div></div></div>
                <div class="preview-section"><h5><i class="fas fa-tachometer-alt"></i> الضغط الجوي</h5><div class="row"><div class="col-md-6"><p><strong>🔽 ضغط المحطة:</strong> ${formData.stationPressure || ''} مليبار</p></div><div class="col-md-6"><p><strong>🔼 ضغط سطح البحر:</strong> ${formData.seaLevelPressure || ''} مليبار</p></div></div></div>
                <div class="preview-section"><h5><i class="fas fa-calculator"></i> الحسابات المستخرجة</h5><div class="row"><div class="col-md-4"><p><strong>💦 الرطوبة النسبية:</strong> ${formData.relativeHumidity || ''}%</p></div><div class="col-md-4"><p><strong>🌬️ ضغط بخار الماء:</strong> ${formData.vaporPressure || ''} مليبار</p></div><div class="col-md-4"><p><strong>⚖️ فرق الضغط:</strong> ${formData.vaporPressureDiff || ''} مليبار</p></div></div></div>
                <div class="preview-section"><h5><i class="fas fa-wind"></i> الرياح</h5><div class="row"><div class="col-md-3"><p><strong>🧭 الاتجاه السطحي:</strong> ${formData.windDirection || ''}°</p></div><div class="col-md-3"><p><strong>🌬️ السرعة السطحية:</strong> ${formData.windSpeed || ''} م/ثا</p></div><div class="col-md-3"><p><strong>🧭 متوسط الاتجاه:</strong> ${formData.avgWindDirection || ''}°</p></div><div class="col-md-3"><p><strong>🌬️ متوسط السرعة:</strong> ${formData.avgWindSpeed || ''} م/ثا</p></div></div></div>
                <div class="preview-section"><h5><i class="fas fa-eye"></i> الرؤية والطقس</h5><div class="row"><div class="col-md-4"><p><strong>👀 الرؤية:</strong> ${formData.visibility || ''} (مئات الأمتار)</p></div><div class="col-md-4"><p><strong>☁️ الطقس الحاضر:</strong> ${formData.currentWeather || ''}</p></div><div class="col-md-4"><p><strong>⏪ الطقس الغابر:</strong> ${formData.pastWeather || ''}</p></div></div></div>
                ${formData.precipitationAmount ? `<div class="preview-section"><h5><i class="fas fa-cloud-rain"></i> الهطول</h5><p><strong>💧 كمية الهطول:</strong> ${formData.precipitationAmount} ملم</p></div>` : ''}
                <div class="preview-section"><h5><i class="fas fa-cloud"></i> السحب</h5><div class="row"><div class="col-md-3"><p><strong>📊 التغطية الكلية:</strong> ${formData.totalCloudCover || ''}/8</p></div><div class="col-md-3"><p><strong>🏔️ ارتفاع الطبقة 1:</strong> ${formData.cloud1Height || ''}0 م</p></div><div class="col-md-3"><p><strong>🏔️ ارتفاع الطبقة 2:</strong> ${formData.cloud2Height || ''}0 م</p></div></div><div class="mt-2"><p><strong>📝 ملاحظات:</strong> ${formData.observerNotes || 'لا توجد ملاحظات'}</p></div></div>
                <div class="alert alert-info mt-3"><i class="fas fa-info-circle"></i> هذا هو معاينة للتقرير. يرجى مراجعة البيانات قبل الإرسال.</div>
            </div>
        `;
    },
    previewData: function() {
        console.log('👁️ عرض معاينة البيانات...');
        if (window.enhancedValidation && window.enhancedValidation.forceFormatAllFields) window.enhancedValidation.forceFormatAllFields();
        const formData = this.collectFormData();
        const userData = this.getUserData();
        const previewContent = this.createPreviewContent(formData, userData);
        const previewContentElement = document.getElementById('previewContent');
        if (previewContentElement) previewContentElement.innerHTML = previewContent;
        this.setupPreviewButtons(formData, userData);
        const previewModal = new bootstrap.Modal(document.getElementById('previewModal'));
        previewModal.show();
        console.log('✅ تم عرض المعاينة');
    },
    setupPreviewButtons: function(formData, userData) {
        const saveJsonBtn = document.getElementById('saveJsonBtn');
        if (saveJsonBtn) saveJsonBtn.onclick = () => this.saveAsJson(formData, userData);
        const sendToDatabaseBtn = document.getElementById('sendToDatabaseBtn');
        if (sendToDatabaseBtn) sendToDatabaseBtn.onclick = async () => { const modal = bootstrap.Modal.getInstance(document.getElementById('previewModal')); if (modal) modal.hide(); if (window.submitHourlyReport) await window.submitHourlyReport(); };
        const whatsappPreviewBtn = document.getElementById('whatsappPreviewBtn');
        if (whatsappPreviewBtn) whatsappPreviewBtn.onclick = () => { if (window.handleWhatsappShare) window.handleWhatsappShare(); };
    },
    saveAsJson: function(formData, userData) {
        console.log('💾 حفظ البيانات كملف JSON...');
        const reportData = { metadata: { reportType: 'hourly', station: userData.stationName, observer: userData.userName, date: document.getElementById('currentDate').value, time: document.getElementById('currentTime').value, utcTime: formData.utcTime, generatedAt: new Date().toISOString() }, measurements: formData };
        const jsonString = JSON.stringify(reportData, null, 2);
        const blob = new Blob([jsonString], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url; a.download = `hourly_report_${userData.stationName}_${formData.utcTime || 'unknown'}_${Date.now()}.json`;
        document.body.appendChild(a); a.click(); document.body.removeChild(a);
        URL.revokeObjectURL(url);
        console.log('✅ تم حفظ الملف');
        if (window.showNotification) window.showNotification(`تم حفظ الملف`, 'success');
    },
    fillTestData: function() {
        console.log('🧪 ملء البيانات التجريبية...');
        const testData = { utcTime: '12', dryTemp: '+25.5', wetTemp: '+20.0', stationPressure: '1013.2', seaLevelPressure: '1013.2', relativeHumidity: '065', dewPoint: '+18.5', vaporPressure: '16.8', vaporPressureDiff: '12.3', windDirection: '18', windSpeed: '12', avgWindDirection: '18', avgWindSpeed: '10', visibility: '050', currentWeather: '01', pastWeather: '0', totalCloudCover: '3', cloud1Amount: '2', cloud1Type: 'Ac', cloud1Height: '150', cloud2Amount: '1', cloud2Type: 'Ci', cloud2Height: '300', cloud3Amount: '', cloud3Type: '', cloud3Height: '', cloud4Amount: '', cover12: '3', cover123: '3', pressureSlope: '2.3', pressureShape: '5', precipitationAmount: '012.5', observerNotes: 'سماء صافية جزئياً مع بعض السحب المتوسطة والمرتفعة.' };
        Object.keys(testData).forEach(fieldName => { const element = document.getElementById(fieldName); if (element) { element.value = testData[fieldName]; if (window.enhancedValidation && window.enhancedValidation.completeFormatting) { setTimeout(() => { window.enhancedValidation.completeFormatting(element); window.enhancedValidation.validateField(element); }, 10); } } });
        const responsibilityCheck = document.getElementById('responsibilityAgreement'); if (responsibilityCheck) responsibilityCheck.checked = true;
        console.log('✅ تم تعبئة البيانات التجريبية');
        if (window.showNotification) window.showNotification('تم تعبئة بيانات تجريبية. يرجى مراجعتها قبل الإرسال.', 'info');
    },
    sendToDatabase: async function() { console.log('📤 إرسال البيانات إلى قاعدة البيانات...'); if (window.submitHourlyReport) return await window.submitHourlyReport(); else { console.error('❌ دالة submitHourlyReport غير متاحة'); return { success: false, message: 'نظام الإرسال غير متاح' }; } }
};
if (typeof window !== 'undefined') window.dataCollector = dataCollector;
document.addEventListener('DOMContentLoaded', function() { console.log('🚀 تهيئة نظام جمع البيانات...'); const previewBtn = document.getElementById('previewReportBtn'); if (previewBtn) previewBtn.addEventListener('click', function(e) { e.preventDefault(); if (window.dataCollector) window.dataCollector.previewData(); }); console.log('✅ نظام جمع البيانات جاهز للاستخدام'); });