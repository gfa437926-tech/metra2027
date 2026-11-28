// whatsapp-share-complete.js
// نظام مشاركة النشرات الزراعية عبر واتساب (نسخة كاملة - جميع الحقول)

class WhatsAppShareComplete {
    constructor() {
        this.init();
    }
    
    init() {
        // تهيئة زر المشاركة
        const whatsappBtn = document.getElementById('whatsappShareBtn');
        if (whatsappBtn) {
            whatsappBtn.addEventListener('click', () => this.shareReport());
        }
    }
    
    shareReport() {
        // التحقق من صحة النموذج أولاً
        if (!this.isFormValid()) {
            this.showNotification('برجاء ملء جميع الحقول المطلوبة قبل المشاركة', 'error');
            return;
        }
        
        // جمع بيانات النموذج (جميع الحقول)
        const reportData = this.collectAllFormData();
        
        // إنشاء الرسالة الكاملة
        const message = this.generateCompleteWhatsAppMessage(reportData);
        
        // ترميز الرسالة للرابط
        const encodedMessage = encodeURIComponent(message);
        
        // إنشاء رابط واتساب (بدون رقم محدد)
        const whatsappUrl = `https://wa.me/?text=${encodedMessage}`;
        
        // فتح واتساب في نافذة جديدة
        window.open(whatsappUrl, '_blank', 'noopener,noreferrer');
        
        // عرض إشعار النجاح
        this.showNotification('تم فتح واتساب مع الرسالة جاهزة، يمكنك الآن اختيار جهة الاتصال', 'success');
    }
    
    collectAllFormData() {
        // جمع جميع الحقول من النموذج
        const formData = {
            // معلومات أساسية
            reportDate: document.getElementById('reportDate').value || 'غير محدد',
            stationName: document.getElementById('userStation').textContent || 'غير محدد',
            observerName: document.getElementById('userName').textContent || 'غير محدد',
            currentDate: document.getElementById('currentDate').value || new Date().toLocaleDateString('ar-SA'),
            
            // درجات الحرارة
            avgAirTemp: document.getElementById('avgAirTemp').value || 'غير مدخل',
            maxAirTemp: document.getElementById('maxAirTemp').value || 'غير مدخل',
            minAirTemp: document.getElementById('minAirTemp').value || 'غير مدخل',
            minTemp2m: document.getElementById('minTemp2m').value || 'غير مدخل',
            maxSoilSurfaceTemp: document.getElementById('maxSoilSurfaceTemp').value || 'غير مدخل',
            minSoilSurfaceTemp: document.getElementById('minSoilSurfaceTemp').value || 'غير مدخل',
            
            // الرطوبة والحسابات
            avgHumidity: document.getElementById('avgHumidity').value || 'غير مدخل',
            minHumidity: document.getElementById('minHumidity').value || 'غير مدخل',
            avgEsE: document.getElementById('avgEsE').value || 'غير مدخل',
            minEsE: document.getElementById('minEsE').value || 'غير مدخل',
            
            // السطوع الشمسي والغيوم
            sunshineHours: document.getElementById('sunshineHours').value || 'غير مدخل',
            totalCloudCover: document.getElementById('totalCloudCover').value || 'غير مدخل',
            lowCloudCover: document.getElementById('lowCloudCover').value || 'غير مدخل',
            
            // الهطول والرياح
            precipitation: document.getElementById('precipitation').value || 'غير مدخل',
            maxWindSpeed: document.getElementById('maxWindSpeed').value || 'غير مدخل',
            classAEvaporation: document.getElementById('classAEvaporation').value || 'غير مدخل',
            avgWindSpeed2m: document.getElementById('avgWindSpeed2m').value || 'غير مدخل',
            
            // درجات حرارة التربة
            avgSoilTemp5cm: document.getElementById('avgSoilTemp5cm').value || 'غير مدخل',
            avgSoilTemp10cm: document.getElementById('avgSoilTemp10cm').value || 'غير مدخل',
            avgSoilTemp20cm: document.getElementById('avgSoilTemp20cm').value || 'غير مدخل',
            avgSoilTemp50cm: document.getElementById('avgSoilTemp50cm').value || 'غير مدخل',
            fieldSoilTemp5cm: document.getElementById('fieldSoilTemp5cm').value || 'غير مدخل',
            fieldSoilTemp10cm: document.getElementById('fieldSoilTemp10cm').value || 'غير مدخل',
            logEvaporation: document.getElementById('logEvaporation').value || 'غير مدخل',
            
            // الظواهر الجوية
            dew: this.getSelectValue('dew'),
            fog: this.getSelectValue('fog'),
            hail: this.getSelectValue('hail'),
            sandstorm: this.getSelectValue('sandstorm'),
            
            // الملاحظات
            observerNotes: document.getElementById('observerNotes').value || 'لا توجد ملاحظات',
        };
        
        return formData;
    }
    
    getSelectValue(elementId) {
        const element = document.getElementById(elementId);
        if (!element) return 'غير محدد';
        
        const value = element.value;
        if (value === "0") return "لا";
        if (value === "1") return "نعم";
        if (value) return value;
        
        return 'غير محدد';
    }
    
    generateCompleteWhatsAppMessage(data) {
        const date = data.reportDate === 'غير محدد' ? data.currentDate : 
                    new Date(data.reportDate).toLocaleDateString('ar-SA');
        
        // إنشاء رسالة منظمة تحتوي على جميع الحقول
        let message = `📊 *النشرة الزراعية الشهرية - التقرير الكامل*
        
📅 التاريخ: ${date}
📍 المحطة: ${data.stationName}
👤 الراصد: ${data.observerName}

━━━━━━━━━━━━━━━━━━━━━━━━
🌡 *البيانات المناخية الرئيسية:*
━━━━━━━━━━━━━━━━━━━━━━━━

• متوسط درجة الحرارة: ${data.avgAirTemp}°س
• أقصى درجة حرارة: ${data.maxAirTemp}°س
• أدنى درجة حرارة: ${data.minAirTemp}°س
• أدنى درجة حرارة على ارتفاع 2م: ${data.minTemp2m}°س
• أقصى درجة حرارة سطح التربة: ${data.maxSoilSurfaceTemp}°س
• أدنى درجة حرارة سطح التربة: ${data.minSoilSurfaceTemp}°س

• متوسط الرطوبة النسبية: ${data.avgHumidity}%
• القيمة الصغرى للرطوبة: ${data.minHumidity}%
• معدل es-e: ${data.avgEsE}
• القيمة الصغرى ل es-e: ${data.minEsE}

━━━━━━━━━━━━━━━━━━━━━━━━
☀ *السطوع الشمسي والغيوم:*
━━━━━━━━━━━━━━━━━━━━━━━━

• مدة السطوع الشمسي: ${data.sunshineHours} ساعة
• معدل التغطية الكلية للغيوم: ${data.totalCloudCover}/8
• معدل تغطية الغيوم المنخفضة: ${data.lowCloudCover}/8

━━━━━━━━━━━━━━━━━━━━━━━━
💧 *الهطول والرياح والتبخر:*
━━━━━━━━━━━━━━━━━━━━━━━━

• كمية الهطول: ${data.precipitation} ملم
• أكبر سرعة رياح: ${data.maxWindSpeed} عقدة
• التبخر من CLASS-A: ${data.classAEvaporation} ملم
• معدل سرعة الرياح على ارتفاع 2م: ${data.avgWindSpeed2m} م/ث
• التبخر من السجل: ${data.logEvaporation} ملم

━━━━━━━━━━━━━━━━━━━━━━━━
🌱 *درجات حرارة التربة:*
━━━━━━━━━━━━━━━━━━━━━━━━

• متوسط حرارة التربة على عمق 5 سم: ${data.avgSoilTemp5cm}°س
• متوسط حرارة التربة على عمق 10 سم: ${data.avgSoilTemp10cm}°س
• متوسط حرارة التربة على عمق 20 سم: ${data.avgSoilTemp20cm}°س
• متوسط حرارة التربة على عمق 50 سم: ${data.avgSoilTemp50cm}°س
• حرارة تربة الحقل على عمق 5 سم: ${data.fieldSoilTemp5cm}°س
• حرارة تربة الحقل على عمق 10 سم: ${data.fieldSoilTemp10cm}°س

━━━━━━━━━━━━━━━━━━━━━━━━
🌪 *الظواهر الجوية:*
━━━━━━━━━━━━━━━━━━━━━━━━

• وجود الندى: ${data.dew}
• وجود الضباب: ${data.fog}
• وجود البرد: ${data.hail}
• وجود عواصف رملية/ترابية: ${data.sandstorm}

━━━━━━━━━━━━━━━━━━━━━━━━
📝 *ملاحظات الراصد:*
━━━━━━━━━━━━━━━━━━━━━━━━

${data.observerNotes}

━━━━━━━━━━━━━━━━━━━━━━━━
🔄 تم إنشاء التقرير عبر نظام إدارة البيانات الجوية
🕒 ${new Date().toLocaleTimeString('ar-SA')}
📅 ${new Date().toLocaleDateString('ar-SA')}`;

        return message;
    }
    
    showNotification(message, type = 'info') {
        // إنشاء عنصر الإشعار
        const notification = document.createElement('div');
        notification.className = `alert alert-${type === 'error' ? 'danger' : 'success'} alert-dismissible fade show`;
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            z-index: 9999;
            min-width: 300px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.2);
            border-radius: 10px;
        `;
        
        notification.innerHTML = `
            <div class="d-flex align-items-center">
                <i class="fas fa-${type === 'error' ? 'exclamation-triangle' : 'check-circle'} me-2 fs-5"></i>
                <div>${message}</div>
            </div>
            <button type="button" class="btn-close" data-bs-dismiss="alert" style="position: absolute; left: 15px; top: 15px;"></button>
        `;
        
        // إضافة الإشعار إلى body
        document.body.appendChild(notification);
        
        // إزالة الإشعار بعد 5 ثوانٍ
        setTimeout(() => {
            if (notification.parentNode) {
                notification.remove();
            }
        }, 5000);
    }
    
    isFormValid() {
        // قائمة جميع الحقول المطلوبة
        const requiredFields = [
            'reportDate',
            'avgAirTemp',
            'maxAirTemp',
            'minAirTemp',
            'avgHumidity',
            'sunshineHours',
            'precipitation',
            'maxWindSpeed',
            'classAEvaporation',
            'dew',
            'fog',
            'hail',
            'sandstorm'
        ];
        
        let isValid = true;
        
        for (const fieldId of requiredFields) {
            const field = document.getElementById(fieldId);
            if (!field || !field.value.trim()) {
                // إظهار رسالة خطأ للحقل المطلوب
                const errorElement = document.getElementById(`${fieldId}Error`);
                if (errorElement) {
                    errorElement.style.display = 'block';
                    field.classList.add('field-invalid');
                    
                    // تمركز الشاشة على الحقل الأول الذي به خطأ
                    if (isValid) {
                        field.scrollIntoView({ behavior: 'smooth', block: 'center' });
                        field.focus();
                    }
                }
                isValid = false;
            }
        }
        
        // التحقق من اتفاقية المسؤولية
        const responsibilityCheckbox = document.getElementById('responsibilityAgreement');
        if (responsibilityCheckbox && !responsibilityCheckbox.checked) {
            this.showNotification('يجب الموافقة على اتفاقية المسؤولية قبل المشاركة', 'error');
            isValid = false;
        }
        
        return isValid;
    }
}

// تهيئة النظام عند تحميل الصفحة
document.addEventListener('DOMContentLoaded', function() {
    window.whatsappShareComplete = new WhatsAppShareComplete();
});